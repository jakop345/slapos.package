/*
 * Syntax:
 *
 *     ipwin command options
 *
 * Get guid of interface:
 *
 *     ipwin guid *MSLOOP re6stnet-lo
 *
 * Install network adapter and rename connection
 *
 *     ipwin install "OemWin2k.inf" tap0901 re6stnet-tcp
 *
 *     ipwin install "netloop.inf" *MSLOOP re6stnet-lo
 *
 * Remove network adapter
 *
 *     ipwin remove tap0901 re6stnet-tcp
 *
 * Run all of testcases:
 *
 *     ipwin test
 *
 */
#include <Windows.h>
#include <tchar.h>
#include <stdio.h>

HRESULT SlaposNetCfgWinCreateNetworkInterface(IN LPCWSTR pInfPath,
                                              IN bool bIsInfPathFile,
                                              IN LPCWSTR pHwid,
                                              IN LPCWSTR pConnectionName,
                                              OUT GUID *pGuid,
                                              OUT BSTR *pErrMsg
                                              );
HRESULT SlaposNetCfgWinRemoveNetworkInterface(IN LPCWSTR pHwid,
                                              IN LPCSTR pGUID,
                                              OUT BSTR *pErrMsg
                                              );
HRESULT SlaposNetCfgGetNetworkInterfaceGuid(IN LPCWSTR pHwid,
                                            IN LPCWSTR pConnectionName,
                                            OUT BSTR *pGUID,
                                            OUT BSTR *pErrMsg
                                            );
void usage()
{
  printf("Usage: ipwin [command] [options] \n\n\
Get guid of interface:\n\
  ipwin guid HWID CONNECTION-NAME\n\n\
For example,\n\
  ipwin guid *MSLOOP re6stnet-lo\n\
\n\
Install network adapter and rename connection:\n\
  ipwin install INF-FILE HWID CONNECTION-NAME\n\n\
For example,\n\
  ipwin install \"OemWin2k.inf\" tap0901 re6stnet-tcp\n\
\n\
  ipwin install \"netloop.inf\" *MSLOOP re6stnet-lo\n\
\n\
Remove network adapter:\n\
  ipwin remove HWID CONNECTIION-NAME\n\n\
For example,\n\
  ipwin remove tap0901 re6stnet-tcp\n\
\n\n\
Exit status:\n\
  0  if OK,\n\
  other value if problems\n\
\n");
}

int _tmain(int argc, TCHAR * argv[])
{
  GUID guid;
  BSTR pErrMsg[1024] = {0};
  BSTR pGUID[512] = {0};

  HRESULT hr = CoInitialize(NULL);

  if (argc == 1) {
    usage();
  }
  else if (wcscmp(argv[1], L"install") == 0) {
    if (argc != 5) {
      usage();
      hr = E_FAIL;
    }
    else
      hr = SlaposNetCfgWinCreateNetworkInterface(argv[2], TRUE, argv[3], argv[4], &guid, pErrMsg);
  }
  else if (wcscmp(argv[1], L"remove") == 0) {
    if (argc != 4) {
      usage();
      hr = E_FAIL;
    }
    else {
      hr = SlaposNetCfgGetNetworkInterfaceGuid(argv[2], argv[3], pGUID, pErrMsg);
      if (hr == S_OK) {
        hr = SlaposNetCfgWinRemoveNetworkInterface(argv[2], (LPCSTR)pGUID, pErrMsg);
      }
    }
  }
  else if (wcscmp(argv[1], L"guid") == 0) {
    if (argc != 4) {
      usage();
      hr = E_FAIL;
    }
    else {
      hr = SlaposNetCfgGetNetworkInterfaceGuid(argv[2], argv[3], pGUID, pErrMsg);
      printf("%s", hr == S_OK ? pGUID : pErrMsg);
    }
  }
  else if (wcscmp(argv[1], L"test") == 0) {
  }
  else {
    usage();
  }

  CoUninitialize();
  return hr == S_OK ? 0 : 1;
}
