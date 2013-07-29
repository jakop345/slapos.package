@ECHO OFF
SETLOCAL

SET CYGWINHOME=%~1\
SET CYGWINROOT="%~1\cygwin"

IF NOT "%CYGWINHOME%" == "" GOTO INIT

SET CYGWINHOME=%~dp0
SET CYGWINROOT="%~dp0cygwin"

:INIT
SET DOWNLOADPATH="%CYGWINHOME%cygwin-packages"
SET SETUPFILE="%CYGWINHOME%setup.exe"
SET OPTIONS=--no-shortcuts --no-startmenu --quiet-mode --no-verify

IF NOT EXIST %SETUPFILE% GOTO START
ECHO Missing %SETUPFILE%
ENDLOCAL
EXIT 1

START:

IF NOT "%2" == "" GOTO REMOTE_INSTALL

:LOCAL_INSTALL
SET PACKAGES=-C All 
ECHO Install cygwin at %CYGWINROOT% from %DOWNLOADPATH% ...
ECHO Packages: %PACKAGES%
%SETUPFILE% --local-install %PACKAGES% -l %DOWNLOADPATH% -R %CYGWINROOT% %OPTIONS%
GOTO END

:REMOTE_INSTALL
SET PACKAGES=-P autobuild -P autoconf -P automake -P autossh -P binutils -P bison -P bzip2 -P ca-certificates -P cron -P curl -P cygport -P cygrunsrv -P file -P flex -P gcc4 -P gdbm -P libgdbm-devel -P gettext -P gettext-devel -P libglib2.0-devel -P libglib2.0_0 -P libexpat1 -P libexpat1-devel -P libmpfr-devel -P libmpfr4 -P libtool -P libxml2 -P libxml2-devel -P libxslt -P libxslt-devel -P make -P m4 -P libncurses-devel -P libncursesw-devel -P patch -P patchutils -P pkg-config -P python -P python-setuptools -P openssh -P openssl-devel -P libopenssl098 -P libopenssl100 -P popt -P readline -P libsqlite3-devel -P libsqlite3_0 -P swig -P syslog-ng -P zlib-devel -P vim -P wget -P libwrap-devel
REM Only required by developer
REM SET PACKAGES=%PACKAGES% -P docbook-utils
SET SITEOPTIONS=-s http://www.netgull.com/cygwin
REM ECHO %2 | FINDSTR \. > /NULL
REM IF %ERRORLEVEL% == 0 SET SITEOPTIONS=--site %2 --only-site
IF /I %2 NEQ network SET SITEOPTIONS=-s %2 --only-site
ECHO Install cygwin at %CYGWINROOT% from %SITE% ...
REM setup.exe -D -X --site http://mirrors.163.com/cygwin -l D:/slapos/slapos-cygwin-packages -R D:/slapos/cygwin 
REM           -P cygrunsrv -P binutils -P gcc4 -P libtool -P make -P autobuild -P autoconf -P automake -P libiconv
%SETUPFILE% %PACKAGES% %SITEOPTIONS% -D -L -l %DOWNLOADPATH% -R %CYGWINROOT% %OPTIONS%
GOTO END

:END
ENDLOCAL
