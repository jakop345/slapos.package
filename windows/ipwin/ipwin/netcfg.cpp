#ifndef _WIN32_WINNT
#define _WIN32_WINNT 0x0600
#endif

#ifndef _UNICODE
#define _UNICODE 1
#endif

#define _WIN32_DCOM
#include <winsock2.h>
#include <Windows.h>
#include <Setupapi.h>

#include <iphlpapi.h>
#include <devguid.h>
#include <stdio.h>
#include <regstr.h>
#include <shlobj.h>
#include <cfgmgr32.h>
#include <tchar.h>
#include <objbase.h>

#include <crtdbg.h>
#include <stdlib.h>
#include <string.h>

#include <Wbemidl.h>
#include <comdef.h>

#include "netcfgn.h"

#define MALLOC(x) HeapAlloc(GetProcessHeap(),HEAP_ZERO_MEMORY,x)
#define FREE(p)   if(NULL != p) {HeapFree(GetProcessHeap(),0,p); p = NULL;}

#define DRIVERHWID L"tap0901"
#define SLAPOS_CONNECTION_NAME L"SlapOS Re6stnet Network"

#define RT_ELEMENTS(aArray)        ( sizeof(aArray) / sizeof((aArray)[0]) )

typedef VOID (*LOG_ROUTINE)(LPCSTR szString);
static LOG_ROUTINE g_Logger = NULL;
static VOID DoLogging(LPCSTR szString, ...);
#define NonStandardLog DoLogging
#define NonStandardLogFlow(x) DoLogging x

static VOID DoLogging(LPCSTR szString, ...)
{
  LOG_ROUTINE pfnRoutine = (LOG_ROUTINE)(*((void * volatile *)&g_Logger));
  if (pfnRoutine)
    {
      char szBuffer[4096] = {0};
      va_list va;
      va_start(va, szString);
      _vsnprintf(szBuffer, RT_ELEMENTS(szBuffer), szString, va);
      va_end(va);

      pfnRoutine(szBuffer);
    }
}

#define SetErrBreak(strAndArgs)                 \
  if (1) {                                      \
    hrc = E_FAIL;                               \
    NonStandardLog strAndArgs;                  \
    break;                                      \
  } else do {} while (0)


#ifndef Assert   /** @todo r=bird: where would this be defined? */
//# ifdef DEBUG
//#  define Assert(_expr) assert(_expr)
//# else
//#  define Assert(_expr) do{ }while (0)
//# endif
# define Assert _ASSERT
# define AssertMsg(expr, msg) do{}while (0)
#endif

/**
 *  Use the IShellFolder API to rename the connection.
 */
static HRESULT rename_shellfolder (PCWSTR wGuid, PCWSTR wNewName)
{
  /* This is the GUID for the network connections folder. It is constant.
   * {7007ACC7-3202-11D1-AAD2-00805FC1270E} */
  const GUID CLSID_NetworkConnections = {
    0x7007ACC7, 0x3202, 0x11D1, {
      0xAA, 0xD2, 0x00, 0x80, 0x5F, 0xC1, 0x27, 0x0E
    }
  };

  LPITEMIDLIST pidl = NULL;
  IShellFolder *pShellFolder = NULL;
  HRESULT hr;

  /* Build the display name in the form "::{GUID}". */
  if (wcslen(wGuid) >= MAX_PATH)
    return E_INVALIDARG;


  WCHAR szAdapterGuid[MAX_PATH + 2] = {0};
  swprintf(szAdapterGuid, L"::%ls", wGuid);
  /* Create an instance of the network connections folder. */
  hr = CoCreateInstance(CLSID_NetworkConnections, NULL,
                        CLSCTX_INPROC_SERVER, IID_IShellFolder,
                        reinterpret_cast<LPVOID *>(&pShellFolder));
  /* Parse the display name. */
  if (SUCCEEDED (hr))
    {
      hr = pShellFolder->ParseDisplayName (NULL, NULL, szAdapterGuid, NULL,
                                           &pidl, NULL);
    }
  if (SUCCEEDED (hr))
    {
      hr = pShellFolder->SetNameOf (NULL, pidl, wNewName, SHGDN_NORMAL,
                                    &pidl);
    }

  CoTaskMemFree (pidl);

  if (pShellFolder)
    pShellFolder->Release();

  return hr;
}

/**
 * Loads a system DLL.
 *
 * @returns Module handle or NULL
 * @param   pszName             The DLL name.
 */
static HMODULE loadSystemDll(const char *pszName)
{
  char   szPath[MAX_PATH];
  UINT   cchPath = GetSystemDirectoryA(szPath, sizeof(szPath));
  size_t cbName  = strlen(pszName) + 1;
  if (cchPath + 1 + cbName > sizeof(szPath))
    return NULL;
  szPath[cchPath] = '\\';
  memcpy(&szPath[cchPath + 1], pszName, cbName);
  return LoadLibraryA(szPath);
}

static HRESULT SlaposNetCfgWinINetCfgLock(IN INetCfg *pNetCfg,
                                          IN LPCWSTR pszwClientDescription,
                                          IN DWORD cmsTimeout,
                                          OUT LPWSTR *ppszwClientDescription)
{
  INetCfgLock *pLock;
  HRESULT hr = pNetCfg->QueryInterface(IID_INetCfgLock, (PVOID*)&pLock);
  if (FAILED(hr))
    {
      NonStandardLogFlow(("QueryInterface failed, hr (0x%x)\n", hr));
      return hr;
    }

  hr = pLock->AcquireWriteLock(cmsTimeout, pszwClientDescription, ppszwClientDescription);
  if (hr == S_FALSE)
    {
      NonStandardLogFlow(("Write lock busy\n"));
    }
  else if (FAILED(hr))
    {
      NonStandardLogFlow(("AcquireWriteLock failed, hr (0x%x)\n", hr));
    }

  pLock->Release();
  return hr;
}

static HRESULT SlaposNetCfgWinINetCfgUnlock(IN INetCfg *pNetCfg)
{
  INetCfgLock *pLock;
  HRESULT hr = pNetCfg->QueryInterface(IID_INetCfgLock, (PVOID*)&pLock);
  if (FAILED(hr))
    {
      NonStandardLogFlow(("QueryInterface failed, hr (0x%x)\n", hr));
      return hr;
    }

  hr = pLock->ReleaseWriteLock();
  if (FAILED(hr))
    NonStandardLogFlow(("ReleaseWriteLock failed, hr (0x%x)\n", hr));

  pLock->Release();
  return hr;
}

HRESULT SlaposNetCfgWinQueryINetCfg(OUT INetCfg **ppNetCfg,
                                    IN BOOL fGetWriteLock,
                                    IN LPCWSTR pszwClientDescription,
                                    IN DWORD cmsTimeout,
                                    OUT LPWSTR *ppszwClientDescription)
{
  INetCfg *pNetCfg;
  HRESULT hr = CoCreateInstance(CLSID_CNetCfg, NULL, CLSCTX_INPROC_SERVER, IID_INetCfg, (PVOID*)&pNetCfg);
  if (FAILED(hr))
    {
      NonStandardLogFlow(("CoCreateInstance failed, hr (0x%x)\n", hr));
      return hr;
    }

  if (fGetWriteLock)
    {
      hr = SlaposNetCfgWinINetCfgLock(pNetCfg, pszwClientDescription, cmsTimeout, ppszwClientDescription);
      if (hr == S_FALSE)
        {
          NonStandardLogFlow(("Write lock is busy\n", hr));
          hr = NETCFG_E_NO_WRITE_LOCK;
        }
    }

  if (SUCCEEDED(hr))
    {
      hr = pNetCfg->Initialize(NULL);
      if (SUCCEEDED(hr))
        {
          *ppNetCfg = pNetCfg;
          return S_OK;
        }
      else
        NonStandardLogFlow(("Initialize failed, hr (0x%x)\n", hr));
    }

  pNetCfg->Release();
  return hr;
}

HRESULT SlaposNetCfgWinReleaseINetCfg(IN INetCfg *pNetCfg, IN BOOL fHasWriteLock)
{
  HRESULT hr = pNetCfg->Uninitialize();
  if (FAILED(hr))
    {
      NonStandardLogFlow(("Uninitialize failed, hr (0x%x)\n", hr));
      return hr;
    }

  if (fHasWriteLock)
    {
      hr = SlaposNetCfgWinINetCfgUnlock(pNetCfg);
      if (FAILED(hr))
        NonStandardLogFlow(("SlaposNetCfgWinINetCfgUnlock failed, hr (0x%x)\n", hr));
    }

  pNetCfg->Release();
  return hr;
}

static HRESULT SlaposNetCfgWinGetComponentByGuidEnum(IEnumNetCfgComponent *pEnumNcc,
                                                     IN const GUID *pGuid,
                                                     OUT INetCfgComponent **ppNcc)
{
  HRESULT hr = pEnumNcc->Reset();
  if (FAILED(hr))
    {
      NonStandardLogFlow(("Reset failed, hr (0x%x)\n", hr));
      return hr;
    }

  INetCfgComponent *pNcc;
  while ((hr = pEnumNcc->Next(1, &pNcc, NULL)) == S_OK)
    {
      ULONG uComponentStatus;
      hr = pNcc->GetDeviceStatus(&uComponentStatus);
      if (SUCCEEDED(hr))
        {
          if (uComponentStatus == 0)
            {
              GUID NccGuid;
              hr = pNcc->GetInstanceGuid(&NccGuid);

              if (SUCCEEDED(hr))
                {
                  if (NccGuid == *pGuid)
                    {
                      /* found the needed device */
                      *ppNcc = pNcc;
                      break;
                    }
                }
              else
                NonStandardLogFlow(("GetInstanceGuid failed, hr (0x%x)\n", hr));
            }
        }

      pNcc->Release();
    }
  return hr;
}

HRESULT SlaposNetCfgWinGetComponentByGuid(IN INetCfg *pNc,
                                          IN const GUID *pguidClass,
                                          IN const GUID * pComponentGuid,
                                          OUT INetCfgComponent **ppncc)
{
  IEnumNetCfgComponent *pEnumNcc;
  HRESULT hr = pNc->EnumComponents(pguidClass, &pEnumNcc);

  if (SUCCEEDED(hr))
    {
      hr = SlaposNetCfgWinGetComponentByGuidEnum(pEnumNcc, pComponentGuid, ppncc);
      if (hr == S_FALSE)
        {
          NonStandardLogFlow(("Component not found\n"));
        }
      else if (FAILED(hr))
        {
          NonStandardLogFlow(("SlaposNetCfgWinGetComponentByGuidEnum failed, hr (0x%x)\n", hr));
        }
      pEnumNcc->Release();
    }
  else
    NonStandardLogFlow(("EnumComponents failed, hr (0x%x)\n", hr));
  return hr;
}

static BOOL SlaposNetCfgWinAdjustNetworkInterfacePriority(IN INetCfg *pNc, IN INetCfgComponent *pNcc, PVOID pContext)
{
  INetCfgComponentBindings *pNetCfgBindings;
  GUID *pGuid = (GUID*)pContext;

  /* Get component's binding. */
  HRESULT hr = pNcc->QueryInterface(IID_INetCfgComponentBindings, (PVOID*)&pNetCfgBindings);
  if (SUCCEEDED(hr))
    {
      /* Get binding path enumerator reference. */
      IEnumNetCfgBindingPath *pEnumNetCfgBindPath;
      hr = pNetCfgBindings->EnumBindingPaths(EBP_BELOW, &pEnumNetCfgBindPath);
      if (SUCCEEDED(hr))
        {
          bool bFoundIface = false;
          hr = pEnumNetCfgBindPath->Reset();
          do
            {
              INetCfgBindingPath *pNetCfgBindPath;
              hr = pEnumNetCfgBindPath->Next(1, &pNetCfgBindPath, NULL);
              if (hr == S_OK)
                {
                  IEnumNetCfgBindingInterface *pEnumNetCfgBindIface;
                  hr = pNetCfgBindPath->EnumBindingInterfaces(&pEnumNetCfgBindIface);
                  if (hr == S_OK)
                    {
                      pEnumNetCfgBindIface->Reset();
                      do
                        {
                          INetCfgBindingInterface *pNetCfgBindIfce;
                          hr = pEnumNetCfgBindIface->Next(1, &pNetCfgBindIfce, NULL);
                          if (hr == S_OK)
                            {
                              INetCfgComponent *pNetCfgCompo;
                              hr = pNetCfgBindIfce->GetLowerComponent(&pNetCfgCompo);
                              if (hr == S_OK)
                                {
                                  ULONG uComponentStatus;
                                  hr = pNetCfgCompo->GetDeviceStatus(&uComponentStatus);
                                  if (hr == S_OK)
                                    {
                                      GUID guid;
                                      hr = pNetCfgCompo->GetInstanceGuid(&guid);
                                      if (   hr == S_OK
                                             && guid == *pGuid)
                                        {
                                          hr = pNetCfgBindings->MoveAfter(pNetCfgBindPath, NULL);
                                          if (FAILED(hr))
                                            NonStandardLogFlow(("Unable to move interface, hr (0x%x)\n", hr));
                                          bFoundIface = true;
                                        }
                                    }
                                  pNetCfgCompo->Release();
                                }
                              else
                                NonStandardLogFlow(("GetLowerComponent failed, hr (0x%x)\n", hr));
                              pNetCfgBindIfce->Release();
                            }
                          else
                            {
                              if (hr == S_FALSE) /* No more binding interfaces? */
                                hr = S_OK;
                              else
                                NonStandardLogFlow(("Next binding interface failed, hr (0x%x)\n", hr));
                              break;
                            }
                        } while (!bFoundIface);
                      pEnumNetCfgBindIface->Release();
                    }
                  else
                    NonStandardLogFlow(("EnumBindingInterfaces failed, hr (0x%x)\n", hr));
                  pNetCfgBindPath->Release();
                }
              else
                {
                  if (hr = S_FALSE) /* No more binding paths? */
                    hr = S_OK;
                  else
                    NonStandardLogFlow(("Next bind path failed, hr (0x%x)\n", hr));
                  break;
                }
            } while (!bFoundIface);
          pEnumNetCfgBindPath->Release();
        }
      else
        NonStandardLogFlow(("EnumBindingPaths failed, hr (0x%x)\n", hr));
      pNetCfgBindings->Release();
    }
  else
    NonStandardLogFlow(("QueryInterface for IID_INetCfgComponentBindings failed, hr (0x%x)\n", hr));
  return TRUE;
}

static UINT WINAPI SlaposNetCfgWinPspFileCallback(PVOID Context,
                                                  UINT Notification,
                                                  UINT_PTR Param1,
                                                  UINT_PTR Param2
                                                  )
{
  switch (Notification)
    {
    case SPFILENOTIFY_TARGETNEWER:
    case SPFILENOTIFY_TARGETEXISTS:
      return TRUE;
    }
  return SetupDefaultQueueCallback(Context, Notification, Param1, Param2);
}

HRESULT SlaposNetCfgWinRenameConnection (LPWSTR pGuid, PCWSTR NewName)
{
  typedef HRESULT (WINAPI *lpHrRenameConnection) (const GUID *, PCWSTR);
  lpHrRenameConnection RenameConnectionFunc = NULL;
  HRESULT status;

  /* First try the IShellFolder interface, which was unimplemented
   * for the network connections folder before XP. */
  status = rename_shellfolder (pGuid, NewName);
  if (status == E_NOTIMPL)
    {
      /** @todo that code doesn't seem to work! */
      /* The IShellFolder interface is not implemented on this platform.
       * Try the (undocumented) HrRenameConnection API in the netshell
       * library. */
      CLSID clsid;
      HINSTANCE hNetShell;
      status = CLSIDFromString ((LPOLESTR) pGuid, &clsid);
      if (FAILED(status))
        return E_FAIL;
      hNetShell = loadSystemDll("netshell.dll");
      if (hNetShell == NULL)
        return E_FAIL;
      RenameConnectionFunc =
        (lpHrRenameConnection) GetProcAddress (hNetShell,
                                               "HrRenameConnection");
      if (RenameConnectionFunc == NULL)
        {
          FreeLibrary (hNetShell);
          return E_FAIL;
        }
      status = RenameConnectionFunc (&clsid, NewName);
      FreeLibrary (hNetShell);
    }
  if (FAILED (status))
    return status;

  return S_OK;
}

typedef BOOL (*SLAPOSNETCFGWIN_NETCFGENUM_CALLBACK) (IN INetCfg *pNetCfg, IN INetCfgComponent *pNetCfgComponent, PVOID pContext);

static HRESULT SlaposNetCfgWinEnumNetCfgComponents(IN INetCfg *pNetCfg,
                                                   IN const GUID *pguidClass,
                                                   SLAPOSNETCFGWIN_NETCFGENUM_CALLBACK callback,
                                                   PVOID pContext)
{
  IEnumNetCfgComponent *pEnumComponent;
  HRESULT hr = pNetCfg->EnumComponents(pguidClass, &pEnumComponent);
  if (SUCCEEDED(hr))
    {
      INetCfgComponent *pNetCfgComponent;
      hr = pEnumComponent->Reset();
      do
        {
          hr = pEnumComponent->Next(1, &pNetCfgComponent, NULL);
          if (hr == S_OK)
            {
              //                ULONG uComponentStatus;
              //                hr = pNcc->GetDeviceStatus(&uComponentStatus);
              //                if (SUCCEEDED(hr))
              BOOL fResult = FALSE;
              if (pNetCfgComponent)
                {
                  if (pContext)
                    fResult = callback(pNetCfg, pNetCfgComponent, pContext);
                  pNetCfgComponent->Release();
                }

              if (!fResult)
                break;
            }
          else
            {
              if (hr == S_FALSE)
                {
                  hr = S_OK;
                }
              else
                NonStandardLogFlow(("Next failed, hr (0x%x)\n", hr));
              break;
            }
        } while (true);
      pEnumComponent->Release();
    }
  return hr;
}

HRESULT SlaposNetCfgWinGenConnectionName(PCWSTR DevName, WCHAR *pBuf, PULONG pcbBuf)
{
  const WCHAR * pSuffix = wcsrchr( DevName, L'#' );
  ULONG cbSize = sizeof(SLAPOS_CONNECTION_NAME);
  ULONG cbSufSize = 0;

  if (pSuffix)
    {
      cbSize += (ULONG)wcslen(pSuffix) * 2;
      cbSize += 2; /* for space */
    }

  if (*pcbBuf < cbSize)
    {
      *pcbBuf = cbSize;
      return E_FAIL;
    }

  wcscpy(pBuf, SLAPOS_CONNECTION_NAME);
  if (pSuffix)
    {
      wcscat(pBuf, L" ");
      wcscat(pBuf, pSuffix);
    }

  return S_OK;
}

HRESULT SlaposNetCfgWinCreateNetworkInterface(IN LPCWSTR pInfPath,
                                              IN bool bIsInfPathFile,
                                              IN LPCWSTR pHwid,
                                              IN LPCWSTR pConnectionName,
                                              OUT GUID *pGuid,
                                              OUT BSTR *pErrMsg
                                              )
{
  HRESULT hrc = S_OK;

  HDEVINFO hDeviceInfo = INVALID_HANDLE_VALUE;
  SP_DEVINFO_DATA DeviceInfoData;
  PVOID pQueueCallbackContext = NULL;
  DWORD ret = 0;
  BOOL found = FALSE;
  BOOL registered = FALSE;
  BOOL destroyList = FALSE;
  WCHAR pWCfgGuidString [50];
  WCHAR DevName[256];

  do
    {
      GUID netGuid;
      SP_DRVINFO_DATA DriverInfoData;
      SP_DEVINSTALL_PARAMS DeviceInstallParams;
      TCHAR className [MAX_PATH];
      DWORD index = 0;
      PSP_DRVINFO_DETAIL_DATA pDriverInfoDetail;
      /* for our purposes, 2k buffer is more
       * than enough to obtain the hardware ID
       * of the SlaposNetAdp driver. */
      DWORD detailBuf [2048];

      HKEY hkey = NULL;
      DWORD cbSize;
      DWORD dwValueType;

      /* initialize the structure size */
      DeviceInfoData.cbSize = sizeof (SP_DEVINFO_DATA);
      DriverInfoData.cbSize = sizeof (SP_DRVINFO_DATA);

      /* copy the net class GUID */
      memcpy(&netGuid, &GUID_DEVCLASS_NET, sizeof(GUID_DEVCLASS_NET));

      /* create an empty device info set associated with the net class GUID */
      hDeviceInfo = SetupDiCreateDeviceInfoList(&netGuid, NULL);
      if (hDeviceInfo == INVALID_HANDLE_VALUE)
        SetErrBreak (("SetupDiCreateDeviceInfoList failed (0x%08X)",
                      GetLastError()));

      /* get the class name from GUID */
      BOOL fResult = SetupDiClassNameFromGuid (&netGuid, className, MAX_PATH, NULL);
      if (!fResult)
        SetErrBreak (("SetupDiClassNameFromGuid failed (0x%08X)",
                      GetLastError()));

      /* create a device info element and add the new device instance
       * key to registry */
      fResult = SetupDiCreateDeviceInfo (hDeviceInfo, className, &netGuid, NULL, NULL,
                                         DICD_GENERATE_ID, &DeviceInfoData);
      if (!fResult)
        SetErrBreak (("SetupDiCreateDeviceInfo failed (0x%08X)",
                      GetLastError()));

      /* select the newly created device info to be the currently
         selected member */
      fResult = SetupDiSetSelectedDevice (hDeviceInfo, &DeviceInfoData);
      if (!fResult)
        SetErrBreak (("SetupDiSetSelectedDevice failed (0x%08X)",
                      GetLastError()));

      if (pInfPath)
        {
          /* get the device install parameters and disable filecopy */
          DeviceInstallParams.cbSize = sizeof(SP_DEVINSTALL_PARAMS);
          fResult = SetupDiGetDeviceInstallParams (hDeviceInfo, &DeviceInfoData,
                                                   &DeviceInstallParams);
          if (fResult)
            {
              memset(DeviceInstallParams.DriverPath, 0, sizeof(DeviceInstallParams.DriverPath));
              size_t pathLenght = wcslen(pInfPath) + 1/* null terminator */;
              if (pathLenght < sizeof(DeviceInstallParams.DriverPath)/sizeof(DeviceInstallParams.DriverPath[0]))
                {
                  memcpy(DeviceInstallParams.DriverPath, pInfPath, pathLenght*sizeof(DeviceInstallParams.DriverPath[0]));

                  if (bIsInfPathFile)
                    {
                      DeviceInstallParams.Flags |= DI_ENUMSINGLEINF;
                    }

                  fResult = SetupDiSetDeviceInstallParams(hDeviceInfo, &DeviceInfoData,
                                                          &DeviceInstallParams);
                  if (!fResult)
                    {
                      DWORD winEr = GetLastError();
                      NonStandardLogFlow(("SetupDiSetDeviceInstallParams failed, winEr (%d)\n", winEr));
                      break;
                    }
                }
              else
                {
                  NonStandardLogFlow(("SetupDiSetDeviceInstallParams faileed: INF path is too long\n"));
                  break;
                }
            }
          else
            {
              DWORD winEr = GetLastError();
              NonStandardLogFlow(("SetupDiGetDeviceInstallParams failed, winEr (%d)\n", winEr));
            }
        }

      /* build a list of class drivers */
      fResult = SetupDiBuildDriverInfoList (hDeviceInfo, &DeviceInfoData,
                                            SPDIT_CLASSDRIVER);
      if (!fResult)
        SetErrBreak (("SetupDiBuildDriverInfoList failed (0x%08X)",
                      GetLastError()));

      destroyList = TRUE;

      /* enumerate the driver info list */
      while (TRUE)
        {
          BOOL ret;

          ret = SetupDiEnumDriverInfo (hDeviceInfo, &DeviceInfoData,
                                       SPDIT_CLASSDRIVER, index, &DriverInfoData);

          /* if the function failed and GetLastError() returned
           * ERROR_NO_MORE_ITEMS, then we have reached the end of the
           * list.  Otherwise there was something wrong with this
           * particular driver. */
          if (!ret)
            {
              if (GetLastError() == ERROR_NO_MORE_ITEMS)
                break;
              else
                {
                  index++;
                  continue;
                }
            }

          pDriverInfoDetail = (PSP_DRVINFO_DETAIL_DATA) detailBuf;
          pDriverInfoDetail->cbSize = sizeof(SP_DRVINFO_DETAIL_DATA);

          /* if we successfully find the hardware ID and it turns out to
           * be the one for the loopback driver, then we are done. */
          if (SetupDiGetDriverInfoDetail (hDeviceInfo,
                                          &DeviceInfoData,
                                          &DriverInfoData,
                                          pDriverInfoDetail,
                                          sizeof (detailBuf),
                                          NULL))
            {
              TCHAR * t;

              /* pDriverInfoDetail->HardwareID is a MULTISZ string.  Go through the
               * whole list and see if there is a match somewhere. */
              t = pDriverInfoDetail->HardwareID;
              while (t && *t && t < (TCHAR *) &detailBuf [RT_ELEMENTS(detailBuf)])
                {
                  if (!_tcsicmp(t, pHwid ? pHwid : DRIVERHWID))
                    break;

                  t += _tcslen(t) + 1;
                }

              if (t && *t && t < (TCHAR *) &detailBuf [RT_ELEMENTS(detailBuf)])
                {
                  found = TRUE;
                  break;
                }
            }

          index ++;
        }

      if (!found)
        SetErrBreak(("Could not find Host Interface Networking driver! Please reinstall"));

      /* set the loopback driver to be the currently selected */
      fResult = SetupDiSetSelectedDriver (hDeviceInfo, &DeviceInfoData,
                                          &DriverInfoData);
      if (!fResult)
        SetErrBreak(("SetupDiSetSelectedDriver failed (0x%08X)",
                     GetLastError()));

      /* register the phantom device to prepare for install */
      fResult = SetupDiCallClassInstaller (DIF_REGISTERDEVICE, hDeviceInfo,
                                           &DeviceInfoData);
      if (!fResult)
        {
          DWORD err = GetLastError();
          SetErrBreak (("SetupDiCallClassInstaller failed (0x%08X)",
                        err));
        }

      /* registered, but remove if errors occur in the following code */
      registered = TRUE;

      /* ask the installer if we can install the device */
      fResult = SetupDiCallClassInstaller (DIF_ALLOW_INSTALL, hDeviceInfo,
                                           &DeviceInfoData);
      if (!fResult)
        {
          if (GetLastError() != ERROR_DI_DO_DEFAULT)
            SetErrBreak (("SetupDiCallClassInstaller (DIF_ALLOW_INSTALL) failed (0x%08X)",
                          GetLastError()));
          /* that's fine */
        }

      /* get the device install parameters and disable filecopy */
      DeviceInstallParams.cbSize = sizeof(SP_DEVINSTALL_PARAMS);
      fResult = SetupDiGetDeviceInstallParams (hDeviceInfo, &DeviceInfoData,
                                               &DeviceInstallParams);
      if (fResult)
        {
          pQueueCallbackContext = SetupInitDefaultQueueCallback(NULL);
          if (pQueueCallbackContext)
            {
              DeviceInstallParams.InstallMsgHandlerContext = pQueueCallbackContext;
              DeviceInstallParams.InstallMsgHandler = (PSP_FILE_CALLBACK)SlaposNetCfgWinPspFileCallback;
              fResult = SetupDiSetDeviceInstallParams (hDeviceInfo, &DeviceInfoData,
                                                       &DeviceInstallParams);
              if (!fResult)
                {
                  DWORD winEr = GetLastError();
                  NonStandardLogFlow(("SetupDiSetDeviceInstallParams failed, winEr (%d)\n", winEr));
                }
              Assert(fResult);
            }
          else
            {
              DWORD winEr = GetLastError();
              NonStandardLogFlow(("SetupInitDefaultQueueCallback failed, winEr (%d)\n", winEr));
            }
        }
      else
        {
          DWORD winEr = GetLastError();
          NonStandardLogFlow(("SetupDiGetDeviceInstallParams failed, winEr (%d)\n", winEr));
        }

      /* install the files first */
      fResult = SetupDiCallClassInstaller (DIF_INSTALLDEVICEFILES, hDeviceInfo,
                                           &DeviceInfoData);
      if (!fResult)
        SetErrBreak (("SetupDiCallClassInstaller (DIF_INSTALLDEVICEFILES) failed (0x%08X)",
                      GetLastError()));
      /* get the device install parameters and disable filecopy */
      DeviceInstallParams.cbSize = sizeof(SP_DEVINSTALL_PARAMS);
      fResult = SetupDiGetDeviceInstallParams (hDeviceInfo, &DeviceInfoData,
                                               &DeviceInstallParams);
      if (fResult)
        {
          DeviceInstallParams.Flags |= DI_NOFILECOPY;
          fResult = SetupDiSetDeviceInstallParams(hDeviceInfo, &DeviceInfoData,
                                                  &DeviceInstallParams);
          if (!fResult)
            SetErrBreak (("SetupDiSetDeviceInstallParams failed (0x%08X)",
                          GetLastError()));
        }

      /*
       * Register any device-specific co-installers for this device,
       */
      fResult = SetupDiCallClassInstaller(DIF_REGISTER_COINSTALLERS,
                                          hDeviceInfo,
                                          &DeviceInfoData);
      if (!fResult)
        SetErrBreak (("SetupDiCallClassInstaller (DIF_REGISTER_COINSTALLERS) failed (0x%08X)",
                      GetLastError()));

      /*
       * install any installer-specified interfaces.
       * and then do the real install
       */
      fResult = SetupDiCallClassInstaller(DIF_INSTALLINTERFACES,
                                          hDeviceInfo,
                                          &DeviceInfoData);
      if (!fResult)
        SetErrBreak (("SetupDiCallClassInstaller (DIF_INSTALLINTERFACES) failed (0x%08X)",
                      GetLastError()));

      fResult = SetupDiCallClassInstaller(DIF_INSTALLDEVICE,
                                          hDeviceInfo,
                                          &DeviceInfoData);
      if (!fResult)
        SetErrBreak (("SetupDiCallClassInstaller (DIF_INSTALLDEVICE) failed (0x%08X)",
                      GetLastError()));

      /* Figure out NetCfgInstanceId */
      hkey = SetupDiOpenDevRegKey(hDeviceInfo,
                                  &DeviceInfoData,
                                  DICS_FLAG_GLOBAL,
                                  0,
                                  DIREG_DRV,
                                  KEY_READ);
      if (hkey == INVALID_HANDLE_VALUE)
        SetErrBreak(("SetupDiOpenDevRegKey failed (0x%08X)", GetLastError()));

      cbSize = sizeof(pWCfgGuidString);
      DWORD ret;
      ret = RegQueryValueExW (hkey, L"NetCfgInstanceId", NULL,
                              &dwValueType, (LPBYTE) pWCfgGuidString, &cbSize);

      RegCloseKey (hkey);

      if (!SetupDiGetDeviceRegistryPropertyW(hDeviceInfo, &DeviceInfoData,
                                             SPDRP_FRIENDLYNAME , /* IN DWORD Property,*/
                                             NULL, /*OUT PDWORD PropertyRegDataType, OPTIONAL*/
                                             (PBYTE)DevName, /*OUT PBYTE PropertyBuffer,*/
                                             sizeof(DevName), /* IN DWORD PropertyBufferSize,*/
                                             NULL /*OUT PDWORD RequiredSize OPTIONAL*/))
        {
          int err = GetLastError();
          if (err != ERROR_INVALID_DATA)
            {
              SetErrBreak (("SetupDiGetDeviceRegistryProperty failed (0x%08X)",
                            err));
            }

          if (!SetupDiGetDeviceRegistryPropertyW(hDeviceInfo, &DeviceInfoData,
                                                 SPDRP_DEVICEDESC, /* IN DWORD Property,*/
                                                 NULL, /*OUT PDWORD PropertyRegDataType, OPTIONAL*/
                                                 (PBYTE)DevName, /*OUT PBYTE PropertyBuffer,*/
                                                 sizeof(DevName), /* IN DWORD PropertyBufferSize,*/
                                                 NULL /*OUT PDWORD RequiredSize OPTIONAL*/
                                                 ))
            {
              err = GetLastError();
              SetErrBreak (("SetupDiGetDeviceRegistryProperty failed (0x%08X)",
                            err));
            }
        }
    }
  while (0);

  /*
   * cleanup
   */
  if (pQueueCallbackContext)
    SetupTermDefaultQueueCallback(pQueueCallbackContext);

  if (hDeviceInfo != INVALID_HANDLE_VALUE)
    {
      /* an error has occurred, but the device is registered, we must remove it */
      if (ret != 0 && registered)
        SetupDiCallClassInstaller(DIF_REMOVE, hDeviceInfo, &DeviceInfoData);

      found = SetupDiDeleteDeviceInfo(hDeviceInfo, &DeviceInfoData);

      /* destroy the driver info list */
      if (destroyList)
        SetupDiDestroyDriverInfoList(hDeviceInfo, &DeviceInfoData,
                                     SPDIT_CLASSDRIVER);
      /* clean up the device info set */
      SetupDiDestroyDeviceInfoList (hDeviceInfo);
    }

  /* return the network connection GUID on success */
  if (SUCCEEDED(hrc))
    {
      HRESULT hr;
      if (pConnectionName) {
        hr = SlaposNetCfgWinRenameConnection(pWCfgGuidString, pConnectionName);
      }
      else {
        WCHAR ConnectoinName[128];
        ULONG cbName = sizeof(ConnectoinName);

        hr = SlaposNetCfgWinGenConnectionName(DevName, ConnectoinName, &cbName);
        if (SUCCEEDED(hr))
          hr = SlaposNetCfgWinRenameConnection(pWCfgGuidString, ConnectoinName);
      }
      // if (lppszName)
      //   {
      //     *lppszName = SysAllocString((const OLECHAR *) DevName);
      //     if (!*lppszName)
      //       {
      //         NonStandardLogFlow(("SysAllocString failed\n"));
      //         hrc = HRESULT_FROM_WIN32(ERROR_NOT_ENOUGH_MEMORY);
      //       }
      //   }


      if (pGuid)
        {
          hrc = CLSIDFromString(pWCfgGuidString, (LPCLSID)pGuid);
          if (FAILED(hrc))
            NonStandardLogFlow(("CLSIDFromString failed, hrc (0x%x)\n", hrc));
        }


      INetCfg *pNetCfg = NULL;
      LPWSTR lpszApp = NULL;
      hr = SlaposNetCfgWinQueryINetCfg(&pNetCfg, TRUE, L"VirtualBox Host-Only Creation",
                                       30 * 1000,
                                       &lpszApp);
      if (hr == S_OK)
        {
          hr = SlaposNetCfgWinEnumNetCfgComponents(pNetCfg,
                                                   &GUID_DEVCLASS_NETSERVICE,
                                                   SlaposNetCfgWinAdjustNetworkInterfacePriority,
                                                   pGuid);
          if (SUCCEEDED(hr))
            {
              hr = SlaposNetCfgWinEnumNetCfgComponents(pNetCfg,
                                                       &GUID_DEVCLASS_NETTRANS,
                                                       SlaposNetCfgWinAdjustNetworkInterfacePriority,
                                                       pGuid);
              if (SUCCEEDED(hr))
                hr = SlaposNetCfgWinEnumNetCfgComponents(pNetCfg,
                                                         &GUID_DEVCLASS_NETCLIENT,
                                                         SlaposNetCfgWinAdjustNetworkInterfacePriority,
                                                         pGuid);
            }

          if (SUCCEEDED(hr))
            {
              hr = pNetCfg->Apply();
            }
          else
            NonStandardLogFlow(("Enumeration failed, hr 0x%x\n", hr));
          SlaposNetCfgWinReleaseINetCfg(pNetCfg, TRUE);
        }
      else if (hr == NETCFG_E_NO_WRITE_LOCK && lpszApp)
        {
          NonStandardLogFlow(("Application %ws is holding the lock, failed\n", lpszApp));
          CoTaskMemFree(lpszApp);
        }
      else
        NonStandardLogFlow(("SlaposNetCfgWinQueryINetCfg failed, hr 0x%x\n", hr));

    }
  return hrc;
}

HRESULT SlaposNetCfgWinRemoveNetworkInterface(IN LPCWSTR pHwid,
                                              IN LPCSTR pGUID,
                                              OUT BSTR *pErrMsg
                                              )
{
  HRESULT hrc = S_OK;

  do
    {
      TCHAR lszPnPInstanceId [512] = {0};

      /* We have to find the device instance ID through a registry search */

      HKEY hkeyNetwork = 0;
      HKEY hkeyConnection = 0;

      do
        {
          WCHAR strRegLocation [256];
          WCHAR wszGuid[50];
          size_t size;

          size = MultiByteToWideChar(CP_ACP,
                                     0,
                                     pGUID,
                                     -1,
                                     NULL,
                                     0
                                     );
          if (size > 50 * sizeof(WCHAR))
            return E_FAIL;
          if (MultiByteToWideChar(CP_ACP,
                                  0,
                                  pGUID,
                                  -1,
                                  wszGuid,
                                  size
                                  ) == 0)
            return E_FAIL;

          // int length = StringFromGUID2(*pGUID, wszGuid, RT_ELEMENTS(wszGuid));
          // if (!length)
          //   SetErrBreak(("Failed to create a Guid string"));
          
          swprintf (strRegLocation,
                    L"SYSTEM\\CurrentControlSet\\Control\\Network\\"
                    L"{4D36E972-E325-11CE-BFC1-08002BE10318}\\%s",
                    wszGuid);

          LONG status;
          status = RegOpenKeyExW (HKEY_LOCAL_MACHINE, strRegLocation, 0,
                                  KEY_READ, &hkeyNetwork);
          if ((status != ERROR_SUCCESS) || !hkeyNetwork)
            SetErrBreak (("Host interface network is not found in registry (%S) [1]",
                          strRegLocation));

          status = RegOpenKeyExW (hkeyNetwork, L"Connection", 0,
                                  KEY_READ, &hkeyConnection);
          if ((status != ERROR_SUCCESS) || !hkeyConnection)
            SetErrBreak (("Host interface network is not found in registry (%S) [2]",
                          strRegLocation));

          DWORD len = sizeof (lszPnPInstanceId);
          DWORD dwKeyType;
          status = RegQueryValueExW (hkeyConnection, L"PnPInstanceID", NULL,
                                     &dwKeyType, (LPBYTE) lszPnPInstanceId, &len);
          if ((status != ERROR_SUCCESS) || (dwKeyType != REG_SZ))
            SetErrBreak (("Host interface network is not found in registry (%S) [3]",
                          strRegLocation));
        }
      while (0);

      if (hkeyConnection)
        RegCloseKey (hkeyConnection);
      if (hkeyNetwork)
        RegCloseKey (hkeyNetwork);

      if (FAILED (hrc))
        break;

      /*
       * Now we are going to enumerate all network devices and
       * wait until we encounter the right device instance ID
       */

      HDEVINFO hDeviceInfo = INVALID_HANDLE_VALUE;

      do
        {
          BOOL ok;
          DWORD ret = 0;
          GUID netGuid;
          SP_DEVINFO_DATA DeviceInfoData;
          DWORD index = 0;
          BOOL found = FALSE;
          DWORD size = 0;

          /* initialize the structure size */
          DeviceInfoData.cbSize = sizeof (SP_DEVINFO_DATA);

          /* copy the net class GUID */
          memcpy (&netGuid, &GUID_DEVCLASS_NET, sizeof (GUID_DEVCLASS_NET));

          /* return a device info set contains all installed devices of the Net class */
          hDeviceInfo = SetupDiGetClassDevs (&netGuid, NULL, NULL, DIGCF_PRESENT);

          if (hDeviceInfo == INVALID_HANDLE_VALUE)
            SetErrBreak (("SetupDiGetClassDevs failed (0x%08X)", GetLastError()));

          /* enumerate the driver info list */
          while (TRUE)
            {
              TCHAR *deviceHwid;

              ok = SetupDiEnumDeviceInfo (hDeviceInfo, index, &DeviceInfoData);

              if (!ok)
                {
                  if (GetLastError() == ERROR_NO_MORE_ITEMS)
                    break;
                  else
                    {
                      index++;
                      continue;
                    }
                }

              /* try to get the hardware ID registry property */
              ok = SetupDiGetDeviceRegistryProperty (hDeviceInfo,
                                                     &DeviceInfoData,
                                                     SPDRP_HARDWAREID,
                                                     NULL,
                                                     NULL,
                                                     0,
                                                     &size);
              if (!ok)
                {
                  if (GetLastError() != ERROR_INSUFFICIENT_BUFFER)
                    {
                      index++;
                      continue;
                    }

                  deviceHwid = (TCHAR *) malloc (size);
                  ok = SetupDiGetDeviceRegistryProperty (hDeviceInfo,
                                                         &DeviceInfoData,
                                                         SPDRP_HARDWAREID,
                                                         NULL,
                                                         (PBYTE)deviceHwid,
                                                         size,
                                                         NULL);
                  if (!ok)
                    {
                      free (deviceHwid);
                      deviceHwid = NULL;
                      index++;
                      continue;
                    }
                }
              else
                {
                  /* something is wrong.  This shouldn't have worked with a NULL buffer */
                  index++;
                  continue;
                }

              for (TCHAR *t = deviceHwid;
                   t && *t && t < &deviceHwid[size / sizeof(TCHAR)];
                   t += _tcslen (t) + 1)
                {
                  if (!_tcsicmp (pHwid ? pHwid : DRIVERHWID, t))
                    {
                      /* get the device instance ID */
                      TCHAR devID [MAX_DEVICE_ID_LEN];
                      if (CM_Get_Device_ID(DeviceInfoData.DevInst,
                                           devID, MAX_DEVICE_ID_LEN, 0) == CR_SUCCESS)
                        {
                          /* compare to what we determined before */
                          if (wcscmp(devID, lszPnPInstanceId) == 0)
                            {
                              found = TRUE;
                              break;
                            }
                        }
                    }
                }

              if (deviceHwid)
                {
                  free (deviceHwid);
                  deviceHwid = NULL;
                }

              if (found)
                break;

              index++;
            }

          if (found == FALSE)
            SetErrBreak (("Host Interface Network driver not found (0x%08X)",
                          GetLastError()));

          ok = SetupDiSetSelectedDevice (hDeviceInfo, &DeviceInfoData);
          if (!ok)
            SetErrBreak (("SetupDiSetSelectedDevice failed (0x%08X)",
                          GetLastError()));

          ok = SetupDiCallClassInstaller (DIF_REMOVE, hDeviceInfo, &DeviceInfoData);
          if (!ok)
            SetErrBreak (("SetupDiCallClassInstaller (DIF_REMOVE) failed (0x%08X)",
                          GetLastError()));
        }
      while (0);

      /* clean up the device info set */
      if (hDeviceInfo != INVALID_HANDLE_VALUE)
        SetupDiDestroyDeviceInfoList (hDeviceInfo);

      if (FAILED (hrc))
        break;
    }
  while (0);

  return hrc;
}

HRESULT SlaposNetCfgGetNetworkInterfaceGuid(IN LPCWSTR pHwid,
                                            IN LPCWSTR pConnectionName,
                                            OUT BSTR *pGUID,
                                            OUT BSTR *pErrMsg
                                            )
{
  HRESULT hrc = S_OK;

  IP_ADAPTER_ADDRESSES *pAdaptAddr = NULL;
  IP_ADAPTER_ADDRESSES *pTmpAdaptAddr = NULL;
  DWORD dwRet = 0;
  DWORD dwSize = 0x10000;

  dwRet = GetAdaptersAddresses(AF_UNSPEC,
                               GAA_FLAG_SKIP_UNICAST            \
                               | GAA_FLAG_SKIP_ANYCAST          \
                               | GAA_FLAG_SKIP_MULTICAST        \
                               | GAA_FLAG_SKIP_DNS_SERVER,
                               NULL,
                               pAdaptAddr,
                               &dwSize
                               );
  if (ERROR_BUFFER_OVERFLOW == dwRet) {
    FREE(pAdaptAddr);
    if (NULL == (pAdaptAddr = (IP_ADAPTER_ADDRESSES*)MALLOC(dwSize)))
      return E_FAIL;
    dwRet = GetAdaptersAddresses(AF_UNSPEC,
                                 GAA_FLAG_SKIP_UNICAST            \
                                 | GAA_FLAG_SKIP_ANYCAST          \
                                 | GAA_FLAG_SKIP_MULTICAST        \
                                 | GAA_FLAG_SKIP_DNS_SERVER,
                                 NULL,
                                 pAdaptAddr,
                                 &dwSize
                                 );
  }

  if (NO_ERROR == dwRet) {
    pTmpAdaptAddr = pAdaptAddr;
    while (pTmpAdaptAddr) {
      if (wcscmp(pConnectionName, pTmpAdaptAddr -> FriendlyName) == 0) {
        memcpy(pGUID, pTmpAdaptAddr -> AdapterName, strlen(pTmpAdaptAddr -> AdapterName));
        // memcpy(pGUID, &(pTmpAdaptAddr -> NetworkGuid), sizeof(pTmpAdaptAddr -> NetworkGuid));
        break;
      }
      pTmpAdaptAddr = pTmpAdaptAddr->Next;
    }
  }
  FREE(pAdaptAddr);

  return hrc;
}
