#! /bin/bash

#
# When cygwin is installed, then call this script by Administrator:
#
#    /bin/bash/ --login -i init-cygwin.sh
# 
# It used to create root account.
#

if [[ ! "$(whoami)" == "Administrator" ]] ; then
    exit 1
fi

if [[ ! -f /etc/passwd ]] ; then
    mkpasswd > /etc/passwd
else
    cp /etc/passwd /etc/passwd.orig
fi

grep -q "^root:" /etc/passwd
if (( $? != 0 )) ; then
    myaccount=$(grep "^Administrator:" /etc/passwd | \
        sed -e "s/500:/0:/" -e "s/Administrator:/root:/g")
    if [[ "${myaccount:0:4}" == root ]] ; then
        echo $myaccount >> /etc/passwd
    else
        exit 1
    fi
fi

if [[ ! -f ~/.minttyrc ]] ; then
    cat <<EOF > ~/.minttyrc
BoldAsFont=no
Font=Courier New
FontHeight=16
Scrollbar=none
EOF
fi

if [[ ! -f /cygtty.bat ]] ; then
    cyghome=$(cygpath -w /)
    cat <<EOF > /cygtty.bat
@echo off

${cyghome:0:2}
chdir ${cyghome}\\bin

start mintty.exe -i /Cygwin-Terminal.ico -
EOF
    chmod +x /cygtty.bat
fi

exit 0

