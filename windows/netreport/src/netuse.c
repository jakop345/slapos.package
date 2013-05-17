/*
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */

#include <Python.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/cygwin.h>

#include <windows.h>
#include <lm.h>
#include <winnetwk.h>

#define MALLOC(x) HeapAlloc(GetProcessHeap(), 0, (x))
#define FREE(x) HeapFree(GetProcessHeap(), 0, (x))

#define MAX_USERBUFFER_SIZE 1024

static char userinfo[MAX_USERBUFFER_SIZE] = { 0 };
static char * logonuser = NULL;
static char * logondomain = NULL;
static char * logonserver = NULL;

static size_t
wchar2mchar(wchar_t *ws, char *buffer, size_t size)
{
  size_t len;
  len = WideCharToMultiByte(CP_ACP,
                            0,
                            ws,
                            -1,
                            NULL,
                            0,
                            NULL,
                            NULL
                            );
  if (len + 1 > size)
    return -1;
  if (WideCharToMultiByte(CP_ACP,
                          0,
                          ws,
                          -1,
                          buffer,
                          len,
                          NULL,
                          NULL
                          ) == 0)
    return -1;
  return len + 1;
}

static PyObject *
netuse_user_info(PyObject *self, PyObject *args)
{
   DWORD dwLevel = 1;
   LPWKSTA_USER_INFO_1 pBuf = NULL;
   NET_API_STATUS nStatus;
   //
   // Call the NetWkstaUserGetInfo function;
   //  specify level 1.
   //
   nStatus = NetWkstaUserGetInfo(NULL,
                                 dwLevel,
                                 (LPBYTE *)&pBuf);
   //
   // If the call succeeds, print the information
   //  about the logged-on user.
   //
   if (nStatus == NERR_Success) {
     if (pBuf != NULL) {
       size_t size = MAX_USERBUFFER_SIZE;
       size_t len;
       logonuser = userinfo;
       len = wchar2mchar(pBuf->wkui1_username, logonuser, size);
       if (len == -1) {
         PyErr_SetString(PyExc_RuntimeError, "Unicode convertion error");
         return NULL;
       }
       size -= len;
       logondomain = logonuser + len;
       len = wchar2mchar(pBuf->wkui1_logon_domain, logondomain, size);
       if (len == -1) {
         PyErr_SetString(PyExc_RuntimeError, "Unicode convertion error");
         return NULL;
       }
       size -= len;
       logonserver = logondomain + len;
       len = wchar2mchar(pBuf->wkui1_logon_server, logonserver, size);
       if (len == -1) {
         PyErr_SetString(PyExc_RuntimeError, "Unicode convertion error");
         return NULL;
       }
     }
   }
   // Otherwise, print the system error.
   //
   else {
     PyErr_Format(PyExc_RuntimeError,
                  "A system error has occurred: %ld",
                  nStatus
                  );
     return NULL;
   }
   //
   // Free the allocated memory.
   //
   if (pBuf != NULL) {
     NetApiBufferFree(pBuf);
     return Py_BuildValue("sss", logonuser, logondomain, logonserver);
   }

   PyErr_SetString(PyExc_RuntimeError, "No logon user information");
   return NULL;
}

static PyObject *
netuse_map_drive(PyObject *self, PyObject *args)
{
  return NULL;
}

static PyObject *
netuse_usage_report(PyObject *self, PyObject *args)
{
  char * servername = NULL;
  PyObject *retvalue = NULL;
  DWORD bitmasks;
  char chdrive = '@';
  char  drivepath[4] = { 'A', ':', '\\', 0 };
  char  drivename[3] = { 'A', ':', 0 };
  ULARGE_INTEGER lFreeBytesAvailable;
  ULARGE_INTEGER lTotalNumberOfBytes;
  ULARGE_INTEGER lTotalNumberOfFreeBytes;

  char szRemoteName[MAX_PATH];
  DWORD dwResult, cchBuff = MAX_PATH;
  DWORD serverlen = 0;

  if (! PyArg_ParseTuple(args, "|s", &servername)) {
    return NULL;
  }

  if (servername) 
    serverlen = strlen(servername);

  bitmasks = GetLogicalDrives();
  if (bitmasks == 0) {
     PyErr_Format(PyExc_RuntimeError,
                  "A system error has occurred in GetLogicalDrives: %ld",
                  GetLastError()
                  );
     return NULL;
  }

  retvalue = PyList_New(0);
  if (retvalue == NULL)
    return NULL;

  while (bitmasks) {
    ++ chdrive;
    drivepath[0] = chdrive;
    drivename[0] = chdrive;

    if ((bitmasks & 1L) == 0) {
      bitmasks >>= 1;
      continue;
    }

    bitmasks >>= 1;
    switch (GetDriveType(drivepath)) {
      case DRIVE_FIXED:
      case DRIVE_REMOTE:
        break;
      default:
        continue;
      }

    dwResult = WNetGetConnection(drivename,
                                 szRemoteName,
                                 &cchBuff
                                 );
    if (dwResult == NO_ERROR) {
      if (servername) {
        if ((cchBuff < serverlen + 3) ||
            (strncmp(servername, szRemoteName+2, serverlen) != 0) ||
            (szRemoteName[serverlen + 2] != '\\')
            )
        continue;
      }
    }

    // The device is not currently connected, but it is a persistent connection.
    else if (dwResult == ERROR_CONNECTION_UNAVAIL) {
      continue;
    }

    // The device is not a redirected device.
    else if (dwResult == ERROR_NOT_CONNECTED) {
      continue;
    }

    else {
      PyErr_Format(PyExc_RuntimeError,
                   "A system error has occurred in WNetGetConnection: %ld",
                   GetLastError()
                   );
      Py_XDECREF(retvalue);
      return NULL;
    }
    
    if (GetDiskFreeSpaceEx(drivepath,
                           &lFreeBytesAvailable,
                           &lTotalNumberOfBytes,
                           &lTotalNumberOfFreeBytes
                           )) {
      PyObject *pobj = Py_BuildValue("ssLLL",
                                     drivename,
                                     szRemoteName,
                                     lFreeBytesAvailable,
                                     lTotalNumberOfFreeBytes,
                                     lTotalNumberOfBytes
                                     );
      if (PyList_Append(retvalue, pobj) == -1) {
        Py_XDECREF(retvalue);
        return NULL;
      }
    }
    else {      
     PyErr_Format(PyExc_RuntimeError,
                  "A system error has occurred in GetDiskFreeSpaceEx(%s): %ld",
                  drivepath,
                  GetLastError()
                  );
     Py_XDECREF(retvalue);
     return NULL;
    }
  }

  return retvalue;
}

static PyMethodDef NetUseMethods[] = {
  {
    "userinfo",
    netuse_user_info,
    METH_VARARGS,
    (
     "userinfo()\n\n"
     "Get the logon user information, return a tuple:\n"
     "(user, domain, server).\n"
     )
  },
  {
    "mapdrive",
    netuse_map_drive,
    METH_VARARGS,
    (
     "mapdrive()\n\n"
     "Create mapped drive from server shared folder\n"
     )
  },
  {
    "usagereport",
    netuse_usage_report,
    METH_VARARGS,
    (
     "usagereport()\n\n"
     "Return a tuple to report all the mapped drive information:\n"
     "(user, domain, drive, usage, total).\n"
     )
  },
  {NULL, NULL, 0, NULL}
};


PyMODINIT_FUNC initnetuse(void)
{
  PyObject* module;
  module = Py_InitModule3("netuse",
                          NetUseMethods,
                          "Show information about net resource in the Windows."
                          );

  if (module == NULL)
    return;
}
