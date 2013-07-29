@ECHO OFF
SETLOCAL

SET CYGWINHOME=%~dp0
SET CYGWINROOT="%~dp0cygwin"

CMD.EXE /C %CYGWINROOT%\bin\bash --login /slapos-build-installer

ENDLOCAL
EXIT 0
