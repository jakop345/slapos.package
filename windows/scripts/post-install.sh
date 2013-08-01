#! /bin/bash
#
# When cygwin is installed, then call this script by Administrator:
#
#    /bin/bash/ --login -i post-install.sh PREFIX
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
#    * Set prefix for this slapos node
#
function show_error_exit()
{
    echo Error: ${1:-"Run post-install script failed."}
    read -n 1 -p "Press any key to exit..."
    exit 1
}
readonly -f show_error_exit

declare -r slapos_prefix=$1
declare -r _cygroot=$(cygpath -w /)

_filename=/etc/passwd
echo "Checking ${_filename} ..."
if [[ ! -f ${_filename} ]] ; then
    mkpasswd -l > ${_filename} || show_error_exit "Error: mkpasswd failed"
    echo "${_filename} has been generated."
else
    echo OK.
fi

_filename=/etc/group
echo "Checking ${_filename} ..."
if [[ ! -f ${_filename} ]] ; then
    mkgroup -l > ${_filename} || show_error_exit "Error: mkgroup failed"
    echo "${_filename} has been generated."
else
    echo OK.
fi

# grep -q "^root:" ${password_filename}
# if (( $? != 0 )) ; then
#     myaccount=$(grep "^Administrator:" ${password_filename} | \
#               sed -e "s/Administrator:unused:500:/root:unused:0:/g")
#     if [[ "${myaccount:0:4}" == root ]] ; then
#         echo $myaccount >> ${password_filename}
#     else
#         exit 1
#     fi
# fi

_charset=$(ipwin codepage) || _charset=""
echo "Windows OEM Codepage is ${_charset}"

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
    echo "${_filename} has been generated."
else
    echo OK.
fi

_filename="/cygtty.bat"
echo Checking  ${_filename} ...
if [[ ! -x ${_filename} ]] ; then
    cat <<EOF > ${_filename}
@echo off

${_cygroot:0:2}
chdir ${_cygroot}\\bin

start mintty.exe -i /Cygwin-Terminal.ico -
EOF
    chmod +x ${_filename}
    echo "${_filename} has been generated."
else
    echo OK.
fi

_filename="/autorebase.bat"
echo Checking  ${_filename} ...
if [[ ! -f ${_filename} ]] ; then
    cat <<EOF > ${_filename}
@echo off
${_cygroot:0:2}
CHDIR ${_cygroot}
${_cygroot}\bin\find /opt/slapos -name "*.dll" > ${_cygroot}\myfile.list
IF EXIST ${_cygroot}\opt\slapgrid. ${_cygroot}\bin\find /opt/slapgrid -name "*.dll" >> ${_cygroot}\myfile.list
bin\bash --login -c "for pid in \$(ps | grep '/usr/bin/openvpn' | gawk '{print $4}') ; do TASKKILL /F /T /PID \$pid ; done"
NET STOP ${slapos_prefix}re6stnet
NET STOP ${slapos_prefix}cygserver
NET STOP ${slapos_prefix}syslog-ng
NET STOP ${slapos_prefix}cron
NET STOP ${slapos_prefix}sshd
bin\bash --login -c "for pid in \$(ps | grep '/usr/bin/python2.7' | gawk '{print \$4}') ; do TASKKILL /F /T /PID \$pid ; done"
PATH .\bin;%PATH%
dash /bin/rebaseall -T /myfile.list -v
EXIT 0
EOF
    chmod +x ${_filename}
    echo "${_filename} has been generated."
else
    echo OK.
fi

# Change format of readme.txt
_filename=$(cygpath -u $(cygpath -m /)/../readme.txt)
if [[ -f ${_filename} ]] ; then
    echo "Changing $(cygpath -w ${_filename}) as dos format ..."
    unix2dos ${_filename} && echo OK.
fi

# Backup slap-runner.html
_filename=/etc/slapos/scripts/slap-runner.html
if [[ -r ${_filename} ]] ; then
    echo "Backuping ${_filename} as ${_filename}.orig"
    cp ${_filename}{,.orig} && echo OK.
else
    echo "Warning: missing ${_filename}"
fi

# Unzip slapos.tar.gz
_filename=/opt/downloads/slapos.tar.gz
if [[ -r ${_filename} ]] ; then
    echo "Extracting ${_filename} ..."
    (cd /opt ; tar xzf ${_filename} --no-same-owner) || show_error_exit
    echo OK.
elif [[ ! -d /opt/slapos ]] ; then
    echo "Warning: missing ${_filename}"
fi

# Patch cygport, so that we can specify package prefix by ourself.
_filename=/usr/bin/cygport
if [[ -f ${_filename} ]] ; then
    echo "Patching ${_filename} ..."
    sed -i -e 's/D="${workdir}\/inst"/D="${CYGCONF_PREFIX-${workdir}\/inst}"/g' ${_filename} &&
    echo OK.
fi
_filename=/usr/share/cygport/cygclass/autotools.cygclass
if [[ -f ${_filename} ]] ; then
    echo "Patching ${_filename} ..."
    sed -i -e 's/prefix=$(__host_prefix)/prefix=${CYGCONF_PREFIX-$(__host_prefix)}/g' ${_filename} &&
    echo OK.
fi
_filename=/usr/share/cygport/cygclass/cmake.cygclass
if [[ -f ${_filename} ]] ; then
    echo "Patching ${_filename} ..."
    sed -i -e 's/-DCMAKE_INSTALL_PREFIX=$(__host_prefix)/-DCMAKE_INSTALL_PREFIX=${CYGCONF_PREFIX-$(__host_prefix)}/g' ${_filename} &&
    echo OK.
fi

# Set prefix for slapos
if [[ -n ${slapos_prefix} ]] ; then
    echo "Set slapos prefix as ${slapos_prefix}"
    sed -i -e "s%slapos_prefix=.*\$%slapos_prefix=${slapos_prefix}%" \
        /etc/slapos/scripts/pre-uninstall.sh /etc/slapos/scripts/slapos-include.sh
else
    echo "Set slapos prefix to empty"
fi

echo
echo "Run post-install.sh script successfully."
echo
read -n 1 -t 60 -p "Press any key to exit..."
exit 0
