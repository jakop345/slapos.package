#! /bin/bash
#
# When cygwin is installed, then call this script by Administrator:
#
#    /bin/bash/ --login -i init-cygwin.sh
# 
# It will do:
#
#    1. Set uid of Adminstrator to 0, and create root account
#
#    2. Create .minttyrc and cygtty.bat, which used to start comand console
#
#    3. Configure cygserver
#
#    4. Configure syslog-ng
#

if [[ ! "$(whoami)" == "Administrator" ]] ; then
    exit 1
fi

if [[ ! -f /etc/passwd ]] ; then
    mkpasswd > /etc/passwd
else
    cp /etc/passwd /etc/passwd.orig
fi

# sed -i -e "s/Administrator:unused:500:/Administrator:unused:0:/g" /etc/passwd
grep -q "^root:" /etc/passwd
if (( $? != 0 )) ; then
    myaccount=$(grep "^Administrator:" /etc/passwd | \
              sed -e "s/Administrator:unused:500:/root:unused:0:/g")
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

# Configure cygserver
/usr/bin/cygserver-config --yes

# Configure syslog-ng
/usr/bin/syslog-ng-config --yes

# Copy rebaseall.bat to /
if [[ -f /etc/postinstall/autorebase.bat.done ]] ; then
    cp /etc/postinstall/autorebase.bat.done /autorebase.bat
fi

# Change format of readme.txt
readme_filepath=$(cygpath -m /)/..
if [[ -f $readme_filepath/Readme.txt ]] ; then
    unix2dos $readme_filepath/Readme.txt
fi

exit 0

