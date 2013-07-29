@ECHO OFF
SETLOCAL

SET CYGWINHOME=%~dp0
SET CYGWINROOT="%~dp0cygwin"

IF "%1" == "slapos-build-installer" GOTO SLAPOS_BUILD_INSTALLER
IF "%1" == "slapos-configure" GOTO SLAPOS_CONFIGURE

CMD.EXE /C %CYGWINROOT%\bin\bash --login %*
SET RETVALUE=%ERRORLEVEL%
GOTO END

:SLAPOS_BUILD_INSTALLER
CMD.EXE /C %CYGWINROOT%\bin\bash --login /slapos-build-installer
SET RETVALUE=%ERRORLEVEL%
GOTO END

:SLAPOS_CONFIGURE
CMD.EXE /C %CYGWINROOT%\bin\bash --login /etc/slapos/scripts/slapos-configure.sh --password=%2 --client-certificate=/certificate --client-key=/key --computer-certificate=/computer.crt --computer-key=/computer.key
SET RETVALUE=%ERRORLEVEL%
GOTO END

:END
ENDLOCAL 
EXIT %RETVALUE%
