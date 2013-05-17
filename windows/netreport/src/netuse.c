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

/* Avoid select function conflict in the winsock2.h */
#define __INSIDE_CYGWIN__
#include <windows.h>

#define MALLOC(x) HeapAlloc(GetProcessHeap(), 0, (x))
#define FREE(x) HeapFree(GetProcessHeap(), 0, (x))

static PyObject *
netuse_init(PyObject *self, PyObject *args)
{
  return NULL;
}

static PyMethodDef NetUseMethods[] = {
  {
    "init",
    netuse_init,
    METH_VARARGS,
    (
     "init()\n\n"
     "Initialize an inotify instance and return a PyCObject, When this\n"
     "PyCObject is reclaimed, GC will free the memory.\n"
     )
  },
  {NULL, NULL, 0, NULL}
};


PyMODINIT_FUNC netuse(void)
{
  PyObject* module;
  module = Py_InitModule3("netuse",
                          NetUseMethods,
                          "Show information about net resource in the Windows."
                          );

  if (module == NULL)
    return;
}
