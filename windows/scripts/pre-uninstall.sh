#! /bin/bash
#
# When uninstall slapos, it will be called by uninstaller. Root right
# required to run this script.
#
#    /bin/bash/ --login -i pre-uninstall.sh
# 
# It will do:
#
#    1. Remove virtual netcards installed by re6stnet
#
#    2. Remove service cron, cygserver and syslog-ng
#

#
# Remove virtual netcard installed by re6stnet 
#
for ifname in $(netsh interface ipv6 show interface | gawk '{ print $5 }') ; do
    if [[ ("$ifname" == re6stnet*) && ("$ifname" != "re6stnet-lo") ]] ; then
        echo Removing network connection: $ifname
        ip vpntap del dev $ifname mode true
    fi
done

#
# Remove services installed by cygwin
#
for x in $(cygrunsrv --list) ; do
    echo Removing cygservice $x
    cygrunsrv -R $x    
done

echo Run pre-uninstall script successfully.
read -n 1 -t 60 -p "Press any key to exit..."
exit 0

