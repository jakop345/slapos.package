/*
 * $Id: security.h 1142 2011-10-05 18:45:49Z g.rodola $
 *
 * Copyright (c) 2009, Jay Loden, Giampaolo Rodola'. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 *
 * Security related functions for Windows platform (Set privileges such as
 * SeDebug), as well as security helper functions.
 */

#include <windows.h>

#if defined(__CYGWIN__)
#define PyErr_SetFromWindowsErr(n) \
  PyErr_Format(PyExc_RuntimeError, "Windoows Error: %d\n", n)
#endif

BOOL SetPrivilege(HANDLE hToken, LPCTSTR Privilege, BOOL bEnablePrivilege);
int SetSeDebug(void);
int UnsetSeDebug(void);
HANDLE token_from_handle(HANDLE hProcess);
int HasSystemPrivilege(HANDLE hProcess);

