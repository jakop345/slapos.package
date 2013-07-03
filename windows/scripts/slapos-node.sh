#! /bin/bash
export PATH=/usr/local/bin:/usr/bin:$PATH

# ======================================================================
# Routine: get_system_and_admins_gids
# Get the ADMINs ids from /etc/group and /etc/passwd
# ======================================================================
get_system_and_admins_ids() {
    ret=0
    for fname in /etc/passwd /etc/group; do
	if ls -ld "${fname}" | grep -Eq  '^-r..r..r..'; then
	    true
	else
	    echo "The file $fname is not readable by all."
	    echo "Please run 'chmod +r $fname'."
	    echo
	    ret=1
	fi
    done

    [ ! -r /etc/passwd -o ! -r  /etc/group ] && return 1;

    ADMINSGID=$(sed -ne '/^[^:]*:S-1-5-32-544:.*:/{s/[^:]*:[^:]*:\([0-9]*\):.*$/\1/p;q}' /etc/group)
    SYSTEMGID=$(sed -ne '/^[^:]*:S-1-5-18:.*:/{s/[^:]*:[^:]*:\([0-9]*\):.*$/\1/p;q}' /etc/group)
    if [ -z "$ADMINSGID" -o -z "$SYSTEMGID" ]; then
		echo "It appears that you do not have correct entries for the"
		echo "ADMINISTRATORS and/or SYSTEM sids in /etc/group."
		echo
		echo "Use the 'mkgroup' utility to generate them"
		echo "   mkgroup -l > /etc/group"
		warning_for_etc_file group
		ret=1;
    fi

    ADMINSUID=$(sed -ne '/^[^:]*:[^:]*:[0-9]*:[0-9]*:[^:]*,S-1-5-32-544:.*:/{s/[^:]*:[^:]*:\([0-9]*\):.*$/\1/p;q}' /etc/passwd)
    SYSTEMUID=$(sed -ne '/^[^:]*:[^:]*:[0-9]*:[0-9]*:[^:]*,S-1-5-18:.*:/{s/[^:]*:[^:]*:\([0-9]*\):.*$/\1/p;q}' /etc/passwd)
    if [ -z "$ADMINSUID" -o -z "$SYSTEMUID" ]; then
		echo "It appears that you do not have correct entries for the"
		echo "ADMINISTRATORS and/or SYSTEM sids in /etc/passwd."
		echo
		echo "Use the 'mkpasswd' utility to generate it"
		echo "   mkpasswd -l > /etc/passwd."
		warning_for_etc_file passwd
		ret=1;
    fi
    return "${ret}"
}  # === get_system_and_admins_ids() === #

#
# Check ipv6 connection by default ipv6 route
#
function check_ipv6_connection()
{
    netsh interface ipv6 show route | grep -q " ::/0 "
}

#
# Check cygwin service
#
function check_cygwin_service()
{
    service_name=$1
    echo Checking $1 service ...

    if [ ! -e /usr/bin/cygrunsrv.exe ]; then
        show_error_exit "No cygserver found, please install the cygrunsrv package first."
    fi

    service_account="$(cygrunsrv -VQ $service_name | sed -n -e 's/^Account[ :]*//p')" || \
        show_error_exit "No $1 service install, please run Configure SlapOS to install it."

    service_state=$(cygrunsrv --query $service_name | sed -n -e 's/^Current State[ :]*//p')
    if [[ ! x$service_state == "xRunning" ]] ; then
        echo "Cygwin service $1 currnt state is $service_state, try to use"
        echo "  cygrunsrv --start $1 to start this service"
        cygrunsrv --start $1 || show_error_exit "Failed to start service $1"
        echo Cygwin $1 service is running.
    fi
    echo Check $1 service OVER.
}

#
# Show error message and waiting for user to press any key quit
#
function show_error_exit()
{
    msg=${1-Failed to configure Slapos Node in this computer.}
    echo $msg
    read -n 1 -p "Press any key to exit..."
    exit 1
}

#-------------------------------------------------
# Check adminsitrator rights
#-------------------------------------------------
get_system_and_admins_ids ||  show_error_exit "Failed to get uids of system and amdinistrator account."
id | grep -q "$ADMINSUID(Administrators)" ||  show_error_exit "Error: Administrator right required to run this script."

#-------------------------------------------------
# Constants
#-------------------------------------------------
slapos_ifname=re6stnet-lo

#-------------------------------------------------
# Check cygserver, syslog-ng
#-------------------------------------------------
check_cygwin_service cygserver
check_cygwin_service syslog-ng

#-------------------------------------------------
# IPv6 Connection
#-------------------------------------------------
echo "Checking native IPv6 ..."
check_ipv6_connection
# Run re6stnet if no native ipv6
if (( $? )) ; then
    echo "No native IPv6."
    echo Check re6stnet network ...
    which re6stnet > /dev/null 2>&1 || show_error_exit "Error: no re6stnet installed, please run Configure SlapOS first."
    service_name=slapos-re6stnet
    # re6st-conf --registry http://re6stnet.nexedi.com/ --is-needed
    cygrunsrv --query $service_name >/dev/null 2>&1
    if (( $? )) ; then
        [[ -d /var/log/re6stnet ]] || mkdir -p /var/log/re6stnet
        echo "Install slapos-re6stnet service ..."
        cygrunsrv -I $service_name -c /etc/re6stnet -p $(which re6stnet) -a "@re6stnet.conf" -u Administrator|| \
            show_error_exit "Failed to install $service_name service."
        echo "Cygwin $service_name service installed."
        # echo "Waiting re6stent network work ..."
        # while true ; do
        #     check_ipv6_connection && break
        # done
    fi
    service_state=$(cygrunsrv --query $service_name | sed -n -e 's/^Current State[ :]*//p')
    if [[ ! x$service_state == "xRunning" ]] ; then
        echo "Starting $service_name service ..."
        cygrunsrv --start $service_name || show_error_exit "Failed to start $service_name service."
        service_state=$(cygrunsrv --query $service_name | sed -n -e 's/^Current State[ :]*//p')
    fi    
    [[ x$service_state == "xRunning" ]] || show_error_exit "Failed to start $service_name service."
    echo Cygwin $service_name service is running.
    echo "You can check log files in the /var/log/re6stnet/*.log"
    echo
    echo "re6stnet network OK."
else
    echo "Native IPv6 Found."
fi

#-------------------------------------------------
# Format slapos node, need root right
#-------------------------------------------------
[[ -f /etc/opt/slapos/slapos.cfg ]] || \
    show_error_exit "Error: no node configure file found, please run Configure SlapOS first."

echo "Formating SlapOS Node ..."
/opt/slapos/bin/slapos node format -cv --now || \
    show_error_exit "Failed to run slapos format."

#-------------------------------------------------
# Release software
#-------------------------------------------------

echo "Releasing software ..."
/opt/slapos/bin/slapos node software --verbose

#-------------------------------------------------
# Instance software
#-------------------------------------------------
echo "Creating instance ..."
/opt/slapos/bin/slapos node instance --verbose

#-------------------------------------------------
# Send report
#-------------------------------------------------
echo "Sending report ..."
/opt/slapos/bin/slapos node report --verbose

read -n 1 -t 60 -p "Press any key to exit..."
exit 0
