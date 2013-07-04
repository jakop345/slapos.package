#! /bin/bash
#
# When uninstall slapos, it will be called by uninstaller. Root right
# required to run this script.
#
#    /bin/bash/ --login -i pre-uninstall.sh
# 
# It will do:
#
#    * Remove virtual netcards installed by re6stnet
#
#    * Remove service cron, cygserver and syslog-ng
#
#    * Remove slapos configure script from windows startup item
#
#    * Remove instance root /srv/slapgrid
#    
export PATH=/usr/local/bin:/usr/bin:/usr/sbin:/sbin:/bin:$PATH

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

#
# Remove slapos-configure from windows startup item
#
slapos_run_key='\HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'
slapos_run_entry=slapos-configure
echo Removing startup item "$slapos_run_key\\$slapos_run_entry"
regtool -q unset "$slapos_run_key\\$slapos_run_entry"

#
# Remove default instance root, because it belong to slapuser, and
# would be removed by the windows uninstaller.
#
[[ -f /srv/slapgrid ]] && echo Removing /srv/slapgrid && rm -rf /srv/slapgrid

echo Run pre-uninstall script successfully.
read -n 1 -t 60 -p "Press any key to exit..."
exit 0

