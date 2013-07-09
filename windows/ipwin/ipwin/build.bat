@ECHO OFF

SETLOCAL
SET VCVARSALL="C:\Program Files\Microsoft Visual Studio 9.0\VC\vcvarsall.bata"
SET SETENV="C:\Program Files\Microsoft SDKs\Windows\v7.0\Bin\SetEnv.cmd"

IF /I "%PROCESSOR_ARCHITECTURE%" == "x86" GOTO ARCH_X86 
IF /I "%PROCESSOR_ARCHITECTURE%" == "AMD64" GOTO ARCH_AMD64

ECHO.
ECHO Failed to build, unknown architecture: %PROCESSOR_ARCHITECTURE%
ECHO.
GOTO END

:ARCH_X86
IF EXIST %VCVARSALL%. (    
   %VCVARSALL% 
   cl /D"UNICODE" /D"_UNICODE" ipwin.cpp netcfg.cpp setupapi.lib iphlpapi.lib advapi32.lib
   GOTO END )

ECHO.
ECHO Failed to build ipwin.exe
ECHO.
ECHO Can't find %VCVARSALL%, be sure VC 2008 or later version have been installed.
ECHO If VC is installed on other path, edit this script at first.
ECHO.
GOTO END

:ARCH_AMD64
IF EXIST %SETENV%. ( 
   SETLOCAL ENABLEDELAYEDEXPANSION
   SETLOCAL ENABLEDELAYEDEXPANSION
   CALL %SETENV% 
   cl /D"UNICODE" /D"_UNICODE" ipwin.cpp netcfg.cpp setupapi.lib iphlpapi.lib advapi32.lib
   GOTO END )

ECHO.
ECHO Failed to build ipwin.exe
ECHO.
ECHO Can't find %SETENV%, be sure Microsoft Windows SDK V7 have been installed.
ECHO If it's installed on other path, edit this script at first.
ECHO.
GOTO END

:END
ENDLOCAL
Pause ...
