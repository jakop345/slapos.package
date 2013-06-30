#! /bin/bash
export PATH=/usr/local/bin:/usr/bin:$PATH

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
        echo Warning: Cygwin service $1 currnt state is $service_state, Running is expeted 
        echo Try to use cygrunsrv --start $1 to start this service
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
# Constants
#-------------------------------------------------
slapos_ifname=re6stnet-lo

#-------------------------------------------------
# IPv6 Connection
#-------------------------------------------------

echo "Checking native IPv6 ..."
check_ipv6_connection
# Run re6stnet if no native ipv6
if (( $? )) ; then
    echo "No native IPv6."
    echo Check re6stnet network ...
    which re6stnet > /dev/null || show_error_exit "Error: no re6stnet installed, please run Configure SlapOS first."    
    # re6st-conf --is-needed --registry http://re6stnet.nexedi.com/
    ps -ef | grep -q babeld.exe
    if (( $? )) ; then
        echo "Start re6stnet ..."
        # It need root rights to install tap-driver
        (cd /etc/re6stnet; re6stnet @re6stnet.conf --ovpnlog -I $slapos_ifname -i $slapos_ifname &)
        echo "Start re6stent in the background OK. You can check log files in the /var/log/re6stnet"

        echo "Waiting re6stent network work ..."
        while true ; do
            check_ipv6_connection && break
        done
    fi
    echo "re6stnet network OK."
else
    echo "Native IPv6 Found."
fi

#-------------------------------------------------
# Check cygserver, syslog-ng
#-------------------------------------------------
check_cygwin_service cygserver
check_cygwin_service syslog-ng

#-------------------------------------------------
# Format slapos node, need root right
#-------------------------------------------------
[[ -f /etc/opt/slapos/slapos.cfg ]] || \
    show_error_exit "Error: no node configure file found, please run Configure SlapOS first."    

echo "Run Slapos format ..."
/opt/slapos/bin/slapos node format -cv --now || \
    show_error_exit "Failed to run slapos format."
echo "Format slapos node OK."

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

exit 0
