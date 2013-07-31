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
# Required:
#   grep gawk TASKKILL
#
export PATH=/usr/local/bin:/usr/bin:/usr/sbin:/sbin:/bin:$PATH

function slapos_kill_process()
{
    name=$1
    echo "Try to kill all $name ..."
    for pid in $(ps | grep "$name" | gawk '{print $4}') ; do
        echo "Kill pid $pid"
        TASKKILL /F /T /PID $pid
    done
}
read -f slapos_kill_process

#
# Declare variables
#
declare -r slapos_prefix=
declare -r slapos_administrator=${slapos_prefix:slap}root
declare -r slapos_user_basename=${slapos_prefix:slap}user
declare -r slapos_ifname=${slapos_prefix}re6stnet-lo
declare -r re6stnet_service_name=${slapos_prefix}re6stnet
declare -r cron_service_name=${slapos_prefix}cron
declare -r ssh_service_name=${slapos_prefix}ssh
declare -r syslog_service_name=${slapos_prefix}syslog-ng
declare -r cygserver_service_name=${slapos_prefix}cygserver

#
# Remove services installed by cygwin,
#
echo "Try to stop service ${re6stnet_service_name} ..."
net stop ${re6stnet_service_name} ||
slapos_kill_process /usr/bin/openvpn

for name in ${re6stnet_service_name} ${cron_service_name} \
    ${ssh_service_name} ${syslog_service_name} \
    ${cygserver_service_name} ; do
    echo "Removing ervice $name"
    cygrunsrv -R $name && echo OK.
done

#
# Stop slapos
#
if [[ -x /opt/slapos/bin/slapos ]] ; then
    echo "Stoping slapos node ..."
    /opt/slapos/bin/slapos node stop all && echo OK.
fi
slapos_kill_process /usr/bin/python2.7

#
# Remove virtual netcard installed by slapos
#
echo "Removing network connection ${slapos_ifname}"
ipwin remove *msloop ${slapos_ifname} && echo OK.

#
# Remove users installed by slapos
#
for _name in $(NET USER) ; do
    if [[ "${_name}" == ${slapos_user_basename}* ]] ; then
        echo "Removing user: ${_name}"
        NET USER ${_name} /DELETE && echo OK.
    elif echo "${_name}" | grep -q -E "(sshd)|(cyg_server)|(${slapos_administrator})" ; then
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
# Remove default instance root, because it belong to slapuser, and
# would be removed by the windows uninstaller.
#
[[ -f /srv/slapgrid ]] && echo Removing /srv/slapgrid && rm -rf /srv/slapgrid && echo OK.

echo
echo Run pre-uninstall script complete.
echo
read -n 1 -t 60 -p "Press any key to exit..."
exit 0
