#! /bin/bash
#
# When uninstalling slapos, it will be called by uninstaller. Root right
# required to run this script.
#
#    /bin/bash/ --login -i slapos-cleanup.sh
#
source $(/usr/bin/dirname $0)/slapos-include.sh

function show_usage()
{
    echo "This script is used to remove everything added by slapos node."
    echo ""
    echo "Usage: ./slapos-cleanup.sh"
    echo ""
    echo "  It will do:"
    echo ""
    echo "    * Remove virtual netcards installed by re6stnet"
    echo ""
    echo "    * Remove service cron, cygserver syslog-ng re6stnet"
    echo ""
    echo "    * Remove account/group added by slapos configure script"
    echo ""
    echo "    * Remove instance and software root /srv/slapgrid /opt/slapgrid"
    echo ""
    echo "After run this script, you got a clean enviroments. Then you can run"
    echo "slapos-configure.sh to configure slapos node again."
    echo ""
}
readonly -f show_usage

function slapos_kill_process()
{
    name=$1
    csih_inform "Try to kill all $name ..."
    for pid in $(ps | grep "$name" | gawk '{print $4}') ; do
        csih_inform "Kill pid $pid"
        TASKKILL /F /T /PID $pid
    done
}
readonly -f slapos_kill_process

# -----------------------------------------------------------
# Start script
# -----------------------------------------------------------
csih_inform "Start cleanup slapos node ..."
echo ""

while test $# -gt 0; do
    # Normalize the prefix.
    case "$1" in
    -*=*) optarg=`echo "$1" | sed 's/[-_a-zA-Z0-9]*=//'` ;;
    *) optarg= ;;
    esac

    case "$1" in
    -h | --help)
    show_usage
    exit 0
    ;;
    *)
    show_usage
    exit 1
    ;;
    esac

    # Next please.
    shift
done

#
# Remove services installed by cygwin,
#
for name in ${re6stnet_service_name} ${cron_service_name} \
    ${syslog_service_name} ${cygserver_service_name} ; do
    csih_inform "Removing service $name"
    cygrunsrv -R $name && csih_inform "OK."
done

#
# Stop slapos
#
if [[ -x /opt/slapos/bin/slapos ]] ; then
    csih_inform "Stopping slapos node ..."
    /opt/slapos/bin/slapos node stop all && csih_inform "OK."
fi
slapos_kill_process /usr/bin/python2.7

#
# Remove route entries added by re6stnet
#

#
# Remove virtual netcard installed by slapos
#
csih_inform "Removing network connection ${slapos_ifname}"
ipwin remove *msloop ${slapos_ifname} && csih_inform "OK."

csih_inform "Removing all Tap-Windows Drivers ..."
which devcon >/dev/null 2>&1 && devcon remove tap0901 && csih_inform "OK."

#
# Remove configure files
#
csih_inform "Removing /etc/opt/slapos"
rm -rf /etc/opt/slapos/ && csih_inform "OK."
csih_inform "Removing ~/.slapos"
rm -rf ~/.slapos && csih_inform "OK."

#
# Remove crontab
#
_filename=/var/cron/tabs/${slapos_administrator}
csih_inform "Removing ${_filename}"
rm -rf ${_filename} && csih_inform "OK."

#
# Remove default instance root and software root, because they belong to
# slapuser, and would not be removed by the windows uninstaller.
#
[[ -d /srv/slapgrid ]] && csih_inform "Removing /srv/slapgrid" && rm -rf /srv/slapgrid && csih_inform "OK."
[[ -d /opt/slapgrid ]] && csih_inform "Removing /opt/slapgrid" && rm -rf /opt/slapgrid && csih_inform "OK."

#
# Remove users installed by slapos
#
[[ -d /var/empty ]] && csih_inform "Removing /var/empty" && rm -rf /var/empty && csih_inform "OK."
for _name in $(NET USER) ; do
    if [[ "${_name}" == ${slapos_user_basename}* ]] ; then
        csih_inform "Removing user: ${_name}"
        NET USER ${_name} /DELETE && csih_inform "OK."
    elif echo "${_name}" | grep -q -E "(cyg_server)|(${slapos_administrator})" ; then
        csih_inform "Removing user: ${_name}"
        NET USER ${_name} /DELETE && csih_inform "OK."
    fi
done
csih_inform "Creating /etc/passwd ..."
mkpasswd -l > /etc/passwd && csih_inform "OK."

#
# Remove local group installed by slapos node
#
for _name in $(NET LOCALGROUP | sed -n -e "s/^*//p" | sed -e "s/\\s//g") ; do
    if [[ "${_name}" == grp_${slapos_user_basename}* ]] ; then
        csih_inform "Removing localgroup: ${_name}"
        NET LOCALGROUP ${_name} /DELETE && csih_inform "OK."
    fi
done
csih_inform "Creating /etc/group ..."
mkgroup -l > /etc/group && csih_inform "OK."

# -----------------------------------------------------------
# End script
# -----------------------------------------------------------
echo ""
csih_inform "Run pre-uninstall script complete."
echo ""

read -n 1 -t 60 -p "Press any key to exit..."
exit 0
