#! /bin/bash
#
# When uninstall slapos, it will be called by uninstaller.
#
#    /bin/bash/ --login -i pre-uninstall.sh
# 
# It will do:
#
#    1. Remove service cygserver
#
#    2. Remove service syslog-ng
#
if [[ ! "$(whoami)" == "Administrator" ]] ; then
    exit 1
fi

cygrunsrv.exe --remove syslog-ng
cygrunsrv.exe --remove cygserver

exit 0

