#! /bin/bash
#
# When uninstalling slapos, it will be called by uninstaller. Root right
# required to run this script.
#
#    /bin/bash/ --login -i pre-uninstall.sh
#
# It will do:
#
#    * Remove virtual netcards installed by re6stnet
#
#    * Remove service cron, cygserver syslog-ng re6stnet
#
#    * Remove account/group added by slapos configure script
#
#    * Remove instance and software root /srv/slapgrid /opt/slapgrid
#
# Required:
#   grep gawk TASKKILL
#
source $(/usr/bin/dirname $0)/slapos-include.sh

function slapos_kill_process()
{
    name=$1
    echo "Try to kill all $name ..."
    for pid in $(ps | grep "$name" | gawk '{print $4}') ; do
        echo "Kill pid $pid"
        TASKKILL /F /T /PID $pid
    done
}
readonly -f slapos_kill_process

#
# Remove services installed by cygwin,
#
for name in ${re6stnet_service_name} ${cron_service_name} \
    ${syslog_service_name} ${cygserver_service_name} ; do
    echo "Removing service $name"
    cygrunsrv -R $name && echo OK.
done

#
# Stop slapos
#
if [[ -x /opt/slapos/bin/slapos ]] ; then
    echo "Stopping slapos node ..."
    /opt/slapos/bin/slapos node stop all && echo OK.
fi
slapos_kill_process /usr/bin/python2.7

#
# Remove route entries added by re6stnet
#

#
# Remove virtual netcard installed by slapos
#
echo "Removing network connection ${slapos_ifname}"
ipwin remove *msloop ${slapos_ifname} && echo OK.

echo "Removing all Tap-Windows Drivers ..."
which devcon >/dev/null 2>&1 && devcon remove tap0901 && echo OK.

#
# Remove configure files
#
echo Removing /etc/opt/slapos
rm -rf /etc/opt/slapos/ && echo OK.
echo Removing ~/.slapos
rm -rf ~/.slapos && echo OK.

#
# Remove crontab
#
_filename=/var/cron/tabs/${slapos_administrator}
echo "Removing ${_filename}"
rm -rf ${_filename} && echo OK.

#
# Remove default instance root and software root, because they belong to
# slapuser, and would not be removed by the windows uninstaller.
#
[[ -f /srv/slapgrid ]] && echo "Removing /srv/slapgrid" && rm -rf /srv/slapgrid && echo OK.
[[ -f /opt/slapgrid ]] && echo "Removing /opt/slapgrid" && rm -rf /opt/slapgrid && echo OK.

#
# Remove users installed by slapos
#
[[ -f /var/empty ]] && echo "Removing /var/empty" && rm -rf /var/empty && echo OK.
for _name in $(NET USER) ; do
    if [[ "${_name}" == ${slapos_user_basename}* ]] ; then
        echo "Removing user: ${_name}"
        NET USER ${_name} /DELETE && echo OK.
    elif echo "${_name}" | grep -q -E "(cyg_server)|(${slapos_administrator})" ; then
        echo "Removing user: ${_name}"
        NET USER ${_name} /DELETE && echo OK.
    fi
done
echo "Creating /etc/passwd ..."
mkpasswd -l > /etc/passwd && echo OK.

#
# Remove local group installed by slapos node
#
for _name in $(NET LOCALGROUP | sed -n -e "s/^*//p" | sed -e "s/\\s//g") ; do
    if [[ "${_name}" == grp_${slapos_user_basename}* ]] ; then
        echo "Removing localgroup: ${_name}"
        NET LOCALGROUP ${_name} /DELETE && echo OK.
    fi
done
echo "Creating /etc/group ..."
mkgroup -l > /etc/group && echo OK.

echo
echo Run pre-uninstall script complete.
echo
read -n 1 -t 60 -p "Press any key to exit..."
exit 0
