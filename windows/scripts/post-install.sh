#! /bin/bash
#
# When cygwin is installed, then call this script by Administrator:
#
#    /bin/bash/ --login -i init-cygwin.sh
#
# It will do:
#
#    * Set uid of Adminstrator to 0, and create root account
#
#    * Create .minttyrc and cygtty.bat, which used to start comand console
#
#    * Create autorebase.bat, it used to fix cygwin dll problem
#
#    * Change readme.txt to dos format
#
function show_error_exit()
{
    echo Error: ${1-Run post-install script failed.}
    read -n 1 -p "Press any key to exit..."
    exit 1
}

local cyghome=$(cygpath -w /)
local password_filename=/etc/passwd

echo Checking /etc/passwd ...
if [[ ! -f $password_filename ]] ; then
    mkpasswd -l > $password_filename || show_error_exit "Error: mkpasswd failed"
    echo File /etc/passwd has been generated.
else
    echo OK.
fi

echo Checking /etc/group ...
if [[ ! -f /etc/group ]] ; then
    mkgroup -l > /etc/group || show_error_exit "Error: mkgroup failed"
    echo File /etc/group has been generated.
else
    echo OK.
fi

# grep -q "^root:" $password_filename
# if (( $? != 0 )) ; then
#     myaccount=$(grep "^Administrator:" $password_filename | \
#               sed -e "s/Administrator:unused:500:/root:unused:0:/g")
#     if [[ "${myaccount:0:4}" == root ]] ; then
#         echo $myaccount >> $password_filename
#     else
#         exit 1
#     fi
# fi

echo Checking Windows OEM Codepage ...
_charset=$(ipwin codepage) || _charset=""
echo Windows OEM Codepage is ${_charset}

_filename=".minttyrc"
echo Checking  ${_filename} ...
if [[ ! -f ${_filename} ]] ; then
    cat <<EOF > ${_filename}
BoldAsFont=no
Font=Courier New
FontHeight=16
Scrollbar=none
Locale=C
Charset=${_charset}
EOF
    echo File ${_filename} has been generated.
else
    echo OK.
fi

_filename="/cygtty.bat"
echo Checking  ${_filename} ...
if [[ ! -x ${_filename} ]] ; then
    cat <<EOF > ${_filename}
@echo off

${cyghome:0:2}
chdir ${cyghome}\\bin

start mintty.exe -i /Cygwin-Terminal.ico -
EOF
    chmod +x ${_filename}
    echo File ${_filename} has been generated.
else
    echo OK.
fi

_filename="/autorebase.bat"
echo Checking  ${_filename} ...
if [[ ! -f ${_filename} ]] ; then
    cat <<EOF > ${_filename}
@echo off
${cyghome}\bin\find /opt/slapos -name "*.dll" > /myfile.list
TASKKILL /F /IM openvpn.exe
NET STOP re6stnet
NET STOP cygserver
NET STOP syslog-ng
NET STOP cron
NET STOP sshd
TASKKILL /F /IM python2.7.exe
${cyghome:0:2}
chdir ${cyghome}
path .\bin;%path%
dash /bin/rebaseall -T /myfile.list -v
PAUSE ...
EOF
    chmod +x ${_filename}
    echo File ${_filename} has been generated.
else
    echo OK.
fi

# Change format of readme.txt
_filename=$(cygpath -u $(cygpath -m /)/../readme.txt)
if [[ -f ${_filename} ]] ; then
    echo Changing $(cygpath -w ${_filename}) as dos format ...
    unix2dos ${_filename} && echo OK.
fi

# Remove cygwin services to be sure these services will be configured
# in this cygwin enviroments when there are many cygwin instances
# installed in this computer.
for name in $(cygrunsrv --list) ; do
    echo Removing $name service
    cygrunsrv -R $name || show_error_exit
    echo OK.
done

# Backup slap-runner.html
_filename=/etc/slapos/scripts/slap-runner.html
if [[ -r ${_filename} ]] ; then
    echo Backuping ${_filename} as ${_filename}.orig
    cp ${_filename}{,.orig} && echo OK.
else
    echo Warning: Missing ${_filename}
fi

# Unzip slapos.tar.gz
_filename=/opt/downloads/slapos.tar.gz
if [[ -r ${_filename} ]] ; then
    echo Extracting ${_filename} ...
    (cd /opt ; tar xzf ${_filename} --no-same-owner) || show_error_exit
    echo OK.
elif [[ ! -d /opt/slapos ]] ; then
    echo Warning: Missing ${_filename}
fi

# Patch cygport, so that we can specify package prefix by ourself.
_filename=/usr/bin/cygport
if [[ -f ${_filename} ]] ; then
    echo Patching ${_filename} ...
    sed -i -e 's/D="${workdir}\/inst"/D="${CYGCONF_PREFIX-${workdir}\/inst}"/g' ${_filename} &&
    echo OK.
fi
_filename=/usr/share/cygport/cygclass/autotools.cygclass
if [[ -f ${_filename} ]] ; then
    echo Patching ${_filename} ...
    sed -i -e 's/prefix=$(__host_prefix)/prefix=${CYGCONF_PREFIX-$(__host_prefix)}/g' ${_filename} &&
    echo OK.
fi
_filename=/usr/share/cygport/cygclass/cmake.cygclass
if [[ -f ${_filename} ]] ; then
    echo Patching ${_filename} ...
    sed -i -e 's/-DCMAKE_INSTALL_PREFIX=$(__host_prefix)/-DCMAKE_INSTALL_PREFIX=${CYGCONF_PREFIX-$(__host_prefix)}/g' ${_filename} &&
    echo OK.
fi

echo
echo Run post-install.sh script successfully.
echo
read -n 1 -t 60 -p "Press any key to exit..."
exit 0
