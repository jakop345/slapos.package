#! /bin/bash
#
# When uninstall slapos, it will be called by uninstaller.
#
#    /bin/bash/ --login -i pre-uninstall.sh
# 
# It will do:
#
#    1. Remove virtual netcards installed by re6stnet
#
#    2. Remove service cygserver and syslog-ng
#
if [[ ! "$(whoami)" == "Administrator" ]] ; then
    exit 1
fi

#
# Remove virtual netcard installed by re6stnet 
#
for ifname in $(netsh interface show interface | gawk '{ print $3 }') ; do
    if [[ ("$ifname" == re6stnet*) && ("$ifname" != "re6stnet-lo") ]] ; then
        ip vpntap del dev $ifname mode true
    fi
done

#
# Remove services installed by cygwin
#
cygrunsrv.exe --remove syslog-ng
cygrunsrv.exe --remove cygserver

exit 0

