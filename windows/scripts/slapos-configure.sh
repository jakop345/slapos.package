#! /bin/bash
#
# This script need root rights. Before run it, make sure you have root
# right.
#
# It used to configure slapos node, it could be run at anytime to
# check the configure of slapos node. The main functions:
#
#     * Install msloop network adapter, named to re6stnet-lo
#
#     * ipv6: Ipv6 configure
#
#     * re6stnet: Install re6stnet and register to nexedi re6stnet if it hasn't
#
#     * node: Create node configure file by parameters ca/key
#
#     * client: Create client configure file by parameters ca/key
#
#     * cron: create cron configure file
#
# Usage:
#
#    ./slapos-configure
#
export PATH=/usr/local/bin:/usr/bin:$PATH

for myprofile in ~/.bash_profile ~/.profile ; do
    grep -q "export CYGWIN=server" $myprofile || echo "export CYGWIN=server" >> $myprofile
done

#-------------------------------------------------
# Common functions
#-------------------------------------------------

#
# Return connection name by line, and replace space with '%'
#
function get_all_connections()
{
    netsh interface ipv6 show interface | \
    grep "^[ 0-9]\+ " | \
    sed -e "s/^[ 0-9]\+[a-zA-Z]\+//" -e "s/^\s*//" -e "s/ /%/g"
}

#
# Check all the connection names, and compare the original connection
# list, return the new connection name
#
# If nothing found, return empty
# If more than one, return the first one
#
function get_new_connection()
{
    original_connections=" $* "
    current_connections=$(get_all_connections)

    for name in $current_connections ; do
        [[ ! "$original_connections" == *[\ ]$name[\ ]* ]] && \
        echo ${name//%/ } && return 0
    done
}

#
# Remove all ipv4/ipv6 addresses in the connection re6stnet-lo
#
function reset_connection()
{
    ifname=${1-re6stnet-lo}
    for addr in $(netsh interface ipv6 show address $ifname level=normal | \
                grep "^Manual" | \
                sed -e "s/^\(\w\+\s\+\)\{4\}//") ; do
        netsh interface ipv6 del address $ifname $addr
    done
    netsh interface ip set address $ifname source=dhcp
    # for addr in $(netsh interface ip show address $ifname | \
    #             grep "IP Address:" | \
    #             sed -e "s/IP Address://") ; do
    #     netsh interface del address $ifname $addr
    # done
}

#
# Transfer connection name to GUID
#
function connection2guid()
{
    ifname=${1-re6stnet-lo}
    #
    # This command doesn't work in the Windows 7, Window 8, maybe
    # Vista. Because no guid information in these platforms.
    #
    # netsh interface ipv6 show interface $ifname | \
    #     grep "^GUID\s*:" | \
    #     sed -e "s/^GUID\s*:\s*//"
    #
    # So we use getmac to repleace it:
    getmac /fo list /v | grep -A3 "^Connection Name: *$ifname\$" \
        | grep "^Transport Name:" | sed -e "s/^.*Tcpip_//g"
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

#
# Query the parameter, usage:
#
#   query_parameter ACTUAL EXCPETED MESSAGE
#
function query_parameter()
{
    if [[ X$1 == X || $1 == "*" || $1 == "all" ]] ; then
        return 1
    fi
    if [[ $1 == "?" || $1 == "query" ]] ; then
        read -n 1 -p $3 user_ack
        if [[ X$user_ack == X[Yy] ]] ; then
            return 1
        else
            return 0
        fi
    fi
    if [[ $1 == $2 ]] ; then
        return 1
    fi
    return 0
}

#-------------------------------------------------
# Constants
#-------------------------------------------------
slapos_client_home=~/.slapos
client_configure_file=$slapos_client_home/slapos.cfg
client_certificate_file=$slapos_client_home/certificate
client_key_file=$slapos_client_home/key
client_template_file=/etc/slapos/slapos-client.cfg.example
url_client_template_file=http://git.erp5.org/gitweb/slapos.core.git/blob_plain/HEAD:/slapos-client.cfg.example

node_certificate_file=/etc/opt/slapos/ssl/computer.crt
node_key_file=/etc/opt/slapos/ssl/computer.key
node_config_file=/etc/opt/slapos/slapos.cfg
node_template_file=/etc/slapos/slapos.cfg.example
url_node_template_file=http://git.erp5.org/gitweb/slapos.core.git/blob_plain/HEAD:/slapos.cfg.example

slapos_ifname=re6stnet-lo
# Hope it will not confilct with original network in the local machine
ipv4_local_network=10.201.67.0/24

slapos_runner_file=/etc/slapos/scripts/slap-runner.html
slaprunner_cfg='http://git.erp5.org/gitweb/slapos.git/blob_plain/refs/heads/cygwin-0:/software/slaprunner/software.cfg'
# slaprunner_title="SlapOS-Node-Runner-In-Windows"
slaprunner_title="Node Runner"

#-------------------------------------------------
# Create paths
#-------------------------------------------------

mkdir -p /etc/opt/slapos/ssl/partition_pki
mkdir -p $slapos_client_home

#-------------------------------------------------
# Configure cygwin server services
#-------------------------------------------------

echo Checking cygserver service ...
cygrunsrv --query cygserver > /dev/null 2>&1
if (( $? )) ; then
    echo Run cygserver-config ...
    /usr/bin/cygserver-config --yes || \
        show_error_exit "Failed to run cygserver-config"
else
    echo The cygserver service has been installed.
fi

echo Checking syslog-ng service ...
cygrunsrv --query syslog-ng > /dev/null 2>&1
if (( $? )) ; then
    echo Run syslog-ng-config ...
    /usr/bin/syslog-ng-config --yes || \
        show_error_exit "Failed to run syslog-ng-config"
else
    echo The syslog-ng service has been installed.
fi

# echo Checking cron service ...
# cygrunsrv --query cron > /dev/null
# if (( $? )) ; then
#     echo Run cron-config ...
#     /usr/bin/cron-config --yes || \
#         show_error_exit "Failed to run cron-config"
#     echo OK.
# else
#     echo The cron service has been installed.
# fi

#-------------------------------------------------
# Configure slapos network
#-------------------------------------------------

#
# Add msloop network adapter, ane name it as "re6stnet-lo"
#
echo Checking slapos network adapter: $slapos_ifname ...
original_connections=$(echo $(get_all_connections))
if [[ ! " $original_connections " == *[\ ]$slapos_ifname[\ ]* ]] ; then
    echo Installing slapos network adapter ...
    devcon install $WINDIR\\inf\\netloop.inf *MSLOOP
    connection_name=$(get_new_connection $original_connections)
    [[ "X$connection_name" == "X" ]] && \
        show_error_exit "Add msloop network adapter failed."
    echo
    netsh interface set interface name="$connection_name" newname="$slapos_ifname"
fi
#ip -4 addr add $ipv4_local_network dev $slapos_ifname
# reset_connection $slapos_ifname
echo SlapOS network adapter OK.
echo Slapos ipv4_local_network is $ipv4_local_network

#-------------------------------------------------
# Generate slapos node configure file
#-------------------------------------------------

echo Checking computer certificate file ...
if [[ ! -f $node_certificate_file ]] ; then
    read -p "Where is computer certificate file (/computer.crt): " certificate_file
    [[ X$certificate_file == X ]] && certificate_file=/computer.crt
    [[ ! -f "$certificate_file" ]] && \
        show_error_exit "Certificate file $certificate_file doesn't exists."
    echo "Copy certificate from $certificate_file to $node_certificate_file"
    certificate_file=$(cygpath -u $certificate_file)
    cp $certificate_file $node_certificate_file
else
    echo Found computer certificate file: $node_certificate_file
fi
openssl x509 -noout -in $node_certificate_file || \
    show_error_exit "Invalid computer certificate: $node_certificate_file."
echo Check computer certificate OK.

echo Checking computer guid ...
computer_id=$(grep  CN=COMP $node_certificate_file | sed -e "s/^.*, CN=//g" | sed -e "s%/emailAddress.*\$%%g")
[[ "$computer_id" == COMP-+([0-9]) ]] || \
    show_error_exit "Invalid computer id specified."
echo Computer GUID is: $computer_id

echo Checking computer key file ...
if [[ ! -f $node_key_file ]] ; then
    read -p "Where is computer key file (/computer.key): " key_file
    [[ X$key_file == X ]] && key_file=/computer.key
    [[ ! -f "$key_file" ]] && \
        show_error_exit "Key file $key_file doesn't exists."
    echo "Copy key from $key_file to $node_key_file"
    key_file=$(cygpath -u $key_file)
    cp $key_file $node_key_file
else
    echo Found computer key file: $node_key_file
fi
openssl rsa -noout -in $node_key_file -check || \
    show_error_exit "Invalid computer key: $node_key_file."
echo Check computer key OK.

# Create node configure file, replace interface_name with guid of
# re6stnet-lo
echo Checking computer configure file ...
if [[ ! -f $node_config_file ]] ; then
    [[ -f $node_template_file ]] || \
        (cd /etc/slapos; wget $url_node_template_file -O $node_template_file) || \
        show_error_exit "Download slapos.cfg.example failed."
    echo "Copy computer configure file from $node_template_file to $node_config_file"
    cp $node_template_file $node_config_file
fi

interface_guid=$(connection2guid $slapos_ifname) || \
    show_error_exit "Failed to get guid of interface: $slapos_ifname."

echo Computer configuration information:
echo \t\tinterface name:     $slapos_ifname
echo \t\tGUID:     $interface_guid
echo \t\tipv4_local_network: $ipv4_local_network
echo \t\tcomputer_id:        $computer_id
# generate /etc/slapos/slapos.cfg
sed -i  -e "s%^\\s*interface_name.*$%interface_name = $interface_guid%" \
        -e "s%^#\?\\s*ipv6_interface.*$%# ipv6_interface =%g" \
        -e "s%^ipv4_local_network.*$%ipv4_local_network = $ipv4_local_network%" \
        -e "s%^computer_id.*$%computer_id = $computer_id%" \
        $node_config_file
echo Check computer configure file OK.

#-------------------------------------------------
# Generate slapos client configure file
#-------------------------------------------------

echo Checking client certificate file ...
if [[ ! -f $client_certificate_file ]] ; then
    read -p "Where is client certificate file (/certificate): " certificate_file
    [[ X$certificate_file == X ]] && certificate_file=/certificate
    [[ ! -f "$certificate_file" ]] && \
        show_error_exit "Certificate file $certificate_file doesn't exists."
    echo "Copy client certificate from $certificate_file to $client_certificate_file"
    certificate_file=$(cygpath -u $certificate_file)
    cp $certificate_file $client_certificate_file
fi
openssl x509 -noout -in $client_certificate_file || \
    show_error_exit "Invalid client certificate: $client_certificate_file."
echo Check client certificate Ok.

echo Checking client key file ...
if [[ ! -f $client_key_file ]] ; then
    read -p "Where is client key file (/key): " key_file
    [[ X$key_file == X ]] && key_file=/key
    [[ ! -f "$key_file" ]] && \
        show_error_exit "Key file $key_file doesn't exists."
    echo "Copy client key from $key_file to $client_key_file"
    key_file=$(cygpath -u $key_file)
    cp $key_file $client_key_file
fi
openssl rsa -noout -in $client_key_file -check || \
    show_error_exit "Invalid client key: $client_key_file."
echo Checking computer key OK.

echo Checking client configure file ...
if [[ ! -f $client_configure_file ]] ; then
    [[ -f $client_template_file ]] || \
    (cd /etc/slapos; wget $url_client_template_file -O $client_template_file) || \
    show_error_exit "Download slapos-client.cfg.example failed."
    echo "Copy client configure file from $client_template_file to $client_config_file"
    cp $client_template_file $client_configure_file
fi

echo Client configuration information:
echo     client certificate file: $client_certificate_file
echo     client key file:         $client_key_file
echo
sed -i -e "s%^cert_file.*$%cert_file = $client_certificate_file%" \
       -e "s%^key_file.*$%key_file = $client_key_file%" \
       $client_configure_file
echo Check client configure file OK.

#-------------------------------------------------
# Re6stnet
#-------------------------------------------------

# Check ipv6, install it if it isn't installed.
echo Checking ipv6 protocol ...
netsh interface ipv6 show interface > /dev/null || netsh interface ipv6 install || \
    show_error_exit "Failed to install ipv6 protocol."
echo IPv6 protocol has been installed.

# miniupnpc is required by re6stnet
echo Checking miniupnpc ...
if [[ ! -d /opt/miniupnpc ]] ; then
    [[ -f /miniupnpc.tar.gz ]] || show_error_exit "No package found: /miniupnpc.tar.gz"
    echo "Installing miniupnpc ..."
    cd /opt
    tar xzf /miniupnpc.tar.gz --no-same-owner
    mv $(ls -d miniupnpc-*) miniupnpc
    cd miniupnpc
    make
    python setup.py install || show_error_exit "Failed to install miniupnpc."
    echo "Install miniupnpc OK."
else
    echo Check miniupnpc OK.
fi

# pyOpenSSL is required by re6stnet
echo Checking pyOpenSSL ...
if [[ ! -d /opt/pyOpenSSL ]] ; then
    [[ -f /pyOpenSSL.tar.gz ]] || show_error_exit "No package found: /pyOpenSSL.tar.gz"
    echo "Installing pyOpenSSL ..."
    cd /opt
    tar xzf /pyOpenSSL.tar.gz --no-same-owner
    mv $(ls -d pyOpenSSL-*) pyOpenSSL
    cd pyOpenSSL
    python setup.py install ||  show_error_exit "Failed ot install pyOpenSSL."
    echo "Install pyOpenSSL OK."
else
    echo Check pyOpenSSL OK.
fi

# Install re6stnet
echo Checking re6stnet ...
if [[ ! -d /opt/re6stnet ]] ; then
    echo "Installing re6stnet ..."
    cd /opt
    if [[ -f /re6stnet.tar.gz ]] ; then
        tar xzf /re6stnet.tar.gz --no-same-owner
        mv $(ls -d re6stnet-*) re6stnet
    else
        echo "Clone re6stnet from http://git.erp5.org/repos/re6stnet.git"
		git clone -b cygwin http://git.erp5.org/repos/re6stnet.git
    fi
    cd re6stnet
    python setup.py install || show_error_exit "Failed to install re6stnet."
    echo "Install re6stnet OK."
else
    echo Check re6stnet OK.
fi

echo Checking re6stent configuration ...
mkdir -p /etc/re6stnet
cd /etc/re6stnet
if [[ ! -f re6stnet.conf ]] ; then
    echo Register to http://re6stnet.nexedi.com ...
    # Your subnet: 2001:67c:1254:e:19::/80 (CN=917529/32)
    mysubnet=$(re6st-conf --registry http://re6stnet.nexedi.com/ --anonymous | grep "^Your subnet:") \
        || show_error_exit "Register to nexedi re6stnet failed"
    echo Register OK.
    echo
    echo $mysubnet
    echo
    echo Write subnet information to re6stnet.conf
    echo "# $mysubnet" >> re6stnet.conf
    echo Write "table 0" to re6stnet.conf
    echo "table 0" >> re6stnet.conf

fi
[[ ! -f re6stnet.conf ]] && \
    show_error_exit "Failed to register to nexedi re6stnet: no /etc/re6stnet/re6stnet.conf found."
grep -q "^table " re6stnet.conf || \
    show_error_exit "Error: no parameter 'table 0' found in the /etc/re6stnet/re6stnet.conf"
grep -q "^# Your subnet: " re6stnet.conf || \
    show_error_exit "Error: no subnet found in the /etc/re6stnet/re6stnet.conf"
echo Check re6stnet configuration OK.
echo

#-------------------------------------------------
# Create openvpn tap-windows drivers used by re6stnet
#-------------------------------------------------

# Adding tap-windows driver will break others, so we add all drivers
# here. Get re6stnet client count, then remove extra drivers and add
# required drivers.
#
echo 
echo Installing OpenVPN Tap-Windows Driver ...
echo 
original_connections=$(echo $(get_all_connections))
client_count=$(sed -n -e "s/^client-count *//p" /etc/re6stnet/re6stnet.conf)
[[ -z $client_count ]] && client_count=10
echo Re6stnet client count = $client_count
re6stnet_name_list="re6stnet-tcp re6stnet-udp"
for (( i=1; i<=client_count; i=i+1 )) ; do
    re6stnet_name_list="$re6stnet_name_list re6stnet$i"
done
for re6stnet_ifname in $re6stnet_name_list ; do
    echo Checking interface $re6stnet_ifname ...
    if [[ ! " $original_connections " == *[\ ]$re6stnet_ifname[\ ]* ]] ; then
        echo Installing  interface $re6stnet_ifname ...
        ip vpntap add dev $re6stnet_ifname || show_error_exit "Failed to install openvpn tap-windows driver."
        echo Interface $re6stnet_ifname installed.
    else
        echo $re6stnet_ifname has been installed.
    fi
done
#
# Remove OpenVPN Tap-Windows Driver
# 
# ip vpntap del dev re6stnet-x
#

#-------------------------------------------------
# Create instance of Web Runner
#-------------------------------------------------
grep -q "window.location.href" $slapos_runner_file
if (( $? )) ; then
    echo
    echo Installing Web Runner ...
    echo

    re6stnet_ipv6=$(cat /etc/re6stnet/re6stnet.conf | grep "Your subnet" | \
        sed -e "s/^.*subnet: //g" -e "s/\/80 (CN.*\$/1/g")
    echo "Re6stnet address in this computer: $re6stnet_ipv6"
    netsh interface ipv6 show addr $slapos_ifname level=normal | grep -q $re6stnet_ipv6 || \
        netsh interface ipv6 add addr $slapos_ifname $re6stnet_ipv6
    echo Run slapformat ...
    /opt/slapos/bin/slapos node format -cv --now ||
        show_error_exit "Failed to run slapos format."
    echo
    
    echo "Supply $slaprunner_cfg in the computer $computer_id"
    /opt/slapos/bin/slapos supply  $slaprunner_cfg $computer_id
    echo "Request an instance 'Node Runner' ..."
    while true ; do
        /opt/slapos/bin/slapos node software --verbose
        /opt/slapos/bin/slapos node instance --verbose
        /opt/slapos/bin/slapos node report --verbose
        /opt/slapos/bin/slapos request $client_config_file "Node Runner" $slaprunner_cfg --node computer_guid=$computer_id && break
        sleep 5
    done
    # Connection parameters of instance are:
    #  {'backend_url': 'http://[2001:67c:1254:45::c5d5]:50000',
    #  'cloud9-url': 'http://localhost:9999',
    #  'password_recovery_code': 'e2d01c14',
    #  'ssh_command': 'ssh 2001:67c:1254:45::c5d5 -p 2222',
    #  'url': 'http://softinst39090.host.vifib.net/'}
    slaprunner_url=$(/opt/slapos/bin/slapos request $client_config_file "Node Runner" $slaprunner_cfg --node computer_guid=$computer_id | \
        grep backend_url | sed -e "s/^.*': '//g" -e "s/',.*$//g")
    echo Got node runner url: $slaprunner_url
    [[ -z $slaprunner_url ]] && show_error_exit "Failed to create instance of SlapOS Web Runner."

    cat <<EOF > $slapos_runner_file
<html>
<head><title>SlapOS Web Runner</title>
<script LANGUAGE="JavaScript">
<!--
function openwin() {
  window.location.href = "$slaprunner_url"
}
//-->
</script>
</head>
<body onload="openwin()"/>
</html>
EOF
    echo Generate file: $slapos_runner_file

    # Apply patches to slapos.cookbook for inotifix
    patch_file=/etc/slapos/patches/slapos-cookbook-inotifyx.patch
    if [[ -f $patch_file ]] ; then
        echo "Apply patch: $patch_file"
        for x in $(find /opt/slapgrid/ -name slapos.cookbook-*.egg) ; do
            echo Apply to $x
            cd $x
            patch --dry-run -p1 < $patch_file && patch -p1 < $patch_file
        done
    fi
    echo
    echo Install Web Runner OK.
    echo
fi

#-------------------------------------------------
# Configure crontab
#-------------------------------------------------
crontab_file=/var/cron/tabs/$(whoami)
if [[ ! -f $crontab_file ]] ; then
    cat <<EOF  > $crontab_file
SHELL=/bin/sh
PATH=/usr/bin:/usr/sbin:/sbin:/bin
MAILTO=""

# Run "Installation/Destruction of Software Releases" and "Deploy/Start/Stop Partitions" once per minute
* * * * * Administrator /opt/slapos/bin/slapos node software --verbose --logfile=/opt/slapos/log/slapos-node-software.log > /dev/null 2>&1
* * * * * Administrator /opt/slapos/bin/slapos node instance --verbose --logfile=/opt/slapos/log/slapos-node-instance.log > /dev/null 2>&1

# Run "Destroy Partitions to be destroyed" once per hour
0 * * * * Administrator /opt/slapos/bin/slapos node report --maximal_delay=3600 --verbose --logfile=/opt/slapos/log/slapos-node-report.log > /dev/null 2>&1

# Run "Check/add IPs and so on" once per hour
0 * * * * Administrator /opt/slapos/bin/slapos node format >> /opt/slapos/log/slapos-node-format.log 2>&1


# Make sure we have only good network routes if we use VPN
# * * * * * root if [ -f /etc/opt/slapos/openvpn-needed  ]; then ifconfig tapVPN | grep "Scope:Global" > /dev/null ;if [ $? = 0 ]; then ROUTES=$(ip -6 r l | grep default | awk '{print $5}'); for GW in $ROUTES ; do if [ ! $GW = tapVPN ]; then /sbin/ip -6 route del default dev $GW > /dev/null 2>&1;fi ;done ;fi ;fi
EOF
    echo Cron file $crontab_file created.
fi

echo SlapOS Node configure successfully.
read -n 1 -p "Press any key to exit..."
exit 0
