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
#     * Check IPv6 protocol and install it if require
#
#     * Configure and start cygwin service: cygserver, syslog-ng, sshd
#
#     * config: Create node and client configure file by parameters ca/key
#
#     * re6stnet: Install re6stnet and register to nexedi re6stnet if required
#
#     * cron: create cron configure file
#
#     * startup: add this script as startup item
#
# Usage:
#
#    ./slapos-configure [--install | --query | --overwrite | --uninstall]
#                       [ * | re6stnet | taps | config | cron | startup | runner]
#
#    The action option:
#
#        --install      Install only when the item hasn't been installed
#        --query        Interactive to install all the item
#        --overwite     Overwrite the item even it has been installed
#        --uninstall    Remove the configure item
#
#    Default is --install
#
#    The configure item option:
#
#        *              All the configure item
#        re6stnet       Install re6stent and dependencies
#        taps           Install OpenVPN Tap-Windows Driver for re6stnet
#        config         Generate slapos node and client configure files
#        cron           Generate cron file and start cron job
#        startup        Run slapos-configure.sh on windows startup
#        runner         Install web runner for this node
#
source $(dirname $0)/slapos-include.sh
check_administrator_right

if [[ ! ":$PATH" == :/opt/slapos/bin: ]] ; then
    for profile in ~/.bash_profile ~/.profile ; do
        grep -q "export PATH=/opt/slapos/bin:" $profile || \
            echo "export PATH=/opt/slapos/bin:$$PATH" >> $profile
    done
fi

# cygrunsrv
# devcon
# openssl
# export WINDIR

# -----------------------------------------------------------
# Create paths
# -----------------------------------------------------------
mkdir -p /etc/opt/slapos/ssl/partition_pki
mkdir -p $slapos_client_home
mkdir -p /opt/slapos/log
mkdir -p /etc/slapos/scripts
mkdir -p /etc/re6stnet

# -----------------------------------------------------------
# Configure cygwin services: cygserver syslog-ng sshd
# -----------------------------------------------------------
echo
echo Starting configure cygwin services ...
echo
cygrunsrv --query cygserver > /dev/null 2>&1
if (( $? )) ; then
    echo Run cygserver-config ...
    /usr/bin/cygserver-config --yes || \
        show_error_exit "Failed to run cygserver-config"
else
    echo The cygserver service has been installed.
fi
check_service_state cygserver

echo Checking syslog-ng service ...
cygrunsrv --query syslog-ng > /dev/null 2>&1
if (( $? )) ; then
    echo Run syslog-ng-config ...
    /usr/bin/syslog-ng-config --yes || \
        show_error_exit "Failed to run syslog-ng-config"
else
    echo The syslog-ng service has been installed.
fi
check_service_state syslog-ng
echo
echo Configure cygwin services OK.
echo

# -----------------------------------------------------------
# Install network connection used by slapos node
# -----------------------------------------------------------
echo
echo Starting configure slapos network ...
echo
original_connections=$(echo $(get_all_connections))
if [[ ! " $original_connections " == *[\ ]$slapos_ifname[\ ]* ]] ; then
    echo Installing slapos network adapter ...
    devcon install $WINDIR\\inf\\netloop.inf *MSLOOP
    connection_name=$(get_new_connection $original_connections)
    [[ "X$connection_name" == "X" ]] && \
        show_error_exit "Add msloop network adapter failed."
    echo
    netsh interface set interface name="$connection_name" newname="$slapos_ifname" || \
        show_error_exit "Failed to rename connection to $slapos_ifname."
    interface_guid=$(connection2guid $slapos_ifname) || \
        show_error_exit "Failed to get guid of interface: $slapos_ifname."
fi
#ip -4 addr add $ipv4_local_network dev $slapos_ifname
# reset_connection $slapos_ifname
echo "  Slapos ipv4_local_network is $ipv4_local_network"
echo "  If it confilcts with your local network, change it in the file:"
echo "     $(dirname $0)/slapos-include.sh"
echo
echo Configure slapos network OK.
echo

# -----------------------------------------------------------
# Check IPv6 protocol, install it if it isn't installed
# -----------------------------------------------------------
echo
echo Starting configure IPv6 protocol ...
echo
netsh interface ipv6 show interface > /dev/null || \
    netsh interface ipv6 install || \
    show_error_exit "Failed to install IPv6 protocol."
echo
echo Configure IPv6 protocol OK.
echo

# -----------------------------------------------------------
# config: Generate slapos node and client configure file
# -----------------------------------------------------------
echo
echo Starting configure section config ...
echo
[[ -r $node_template_file && -r $client_template_file ]] || \
    create_template_configure_file || \
    show_error_exit "Failed to create template configure file."

if [[ ! -f $node_certificate_file ]] ; then
    read -p "Where is computer certificate file (/computer.crt): " filename
    [[ -z $filenname ]] && filename="/computer.crt"
    [[ ! -r "$filename" ]] && \
        show_error_exit "Computer certificate file $filename doesn't exists."
    echo "Copy certificate from $filename to $node_certificate_file"
    filename=$(cygpath -u $filename)
    cp $filename $node_certificate_file
else
    echo "Found computer certificate file: $node_certificate_file"
fi
openssl x509 -noout -in $node_certificate_file || \
    show_error_exit "Invalid computer certificate: $node_certificate_file."

if [[ ! -f $node_key_file ]] ; then
    read -p "Where is computer key file (/computer.key): " filename
    [[ -z $filename ]] && filename="/computer.key"
    [[ ! -f "$filename" ]] && \
        show_error_exit "Key file $filename doesn't exists."
    echo "Copy key from $filename to $node_key_file"
    filename=$(cygpath -u $filename)
    cp $filename $node_key_file
else
    echo "Found computer key file: $node_key_file"
fi
openssl rsa -noout -in $node_key_file -check || \
    show_error_exit "Invalid node key: $node_key_file."

if [[ ! -f $node_config_file ]] ; then
    echo "Copy computer configure file from $node_template_file to $node_config_file"
    cp $node_template_file $node_config_file
fi

[[ -z $interface_guid ]] && \
    interface_guid=$(sed -n -e "s/^\\sinterface_name\\s*=\\s*//p" $node_config_file)
[[ -z $interface_guid ]] && \
    interface_guid=$(connection2guid $slapos_ifname)
[[ -z $interface_guid ]] && \
    show_error_exit "Failed to get guid of interface: $slapos_ifname."

computer_guid=$(grep "CN=COMP" $node_certificate_file | \
    sed -e "s/^.*, CN=//g" | sed -e "s%/emailAddress.*\$%%g")
[[ "$computer_guid" == COMP-+([0-9]) ]] || \
    show_error_exit "Invalid computer id '$computer_guid' specified."

echo "Computer configuration information:"
echo "  interface name:     $slapos_ifname"
echo "  GUID:               $interface_guid"
echo "  ipv4_local_network: $ipv4_local_network"
echo "  computer_id:        $computer_guid"
sed -i  -e "s%^\\s*interface_name.*$%interface_name = $interface_guid%" \
        -e "s%^#\?\\s*ipv6_interface.*$%# ipv6_interface =%g" \
        -e "s%^ipv4_local_network.*$%ipv4_local_network = $ipv4_local_network%" \
        -e "s%^computer_id.*$%computer_id = $computer_guid%" \
        $node_config_file

if [[ ! -f $client_certificate_file ]] ; then
    read -p "Where is client certificate file (/certificate): " filename
    [[ -z $filename ]] && certificate_file="/certificate"
    [[ ! -f "$filename" ]] && \
        show_error_exit "Client certificate file $filename doesn't exists."
    echo "Copy client certificate from $filename to $client_certificate_file"
    certificate_file=$(cygpath -u $filename)
    cp $filename $client_certificate_file
fi
openssl x509 -noout -in $client_certificate_file || \
    show_error_exit "Invalid client certificate: $client_certificate_file."

if [[ ! -f $client_key_file ]] ; then
    read -p "Where is client key file (/key): " filename
    [[ -z $filename ]] && key_file="/key"
    [[ ! -f "$filename" ]] && \
        show_error_exit "Key file $filename doesn't exists."
    echo "Copy client key from $filename to $client_key_file"
    key_file=$(cygpath -u $filename)
    cp $filename $client_key_file
fi
openssl rsa -noout -in $client_key_file -check || \
    show_error_exit "Invalid client key: $client_key_file."

if [[ ! -f $client_configure_file ]] ; then
    echo "Copy client configure file from $client_template_file to $client_config_file"
    cp $client_template_file $client_config_file
fi

echo "Client configuration information:"
echo "   client certificate file: $client_certificate_file"
echo "   client key file:         $client_key_file"
sed -i -e "s%^cert_file.*$%cert_file = $client_certificate_file%" \
       -e "s%^key_file.*$%key_file = $client_key_file%" \
       $client_configure_file
echo
echo Configure section config OK.
echo

# -----------------------------------------------------------
# re6stnet: Install required packages and register to nexedi
# -----------------------------------------------------------
echo
echo Starting configure section re6stnet ...
echo

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

echo Checking re6stnet configuration ...
if [[ ! -r $re6stnet_configure_file ]] ; then
    echo "Registering to http://re6stnet.nexedi.com ..."
    cd $(dirname $re6stnet_configure_file)
    # Your subnet: 2001:67c:1254:e:19::/80 (CN=917529/32)
    subnet=$(re6st-conf --registry http://re6stnet.nexedi.com/ --anonymous | \
        grep "^Your subnet:") || \
        show_error_exit "Register to nexedi re6stnet failed"
    [[ -r re6stnet.conf ]] || \
        show_error_exit "No $re6stnet_configure_file found."
    echo Register re6stnet OK.

    echo "Write information to re6stnet.conf:"
    echo "  # $subnet"
    echo "  table 0"
    echo "  ovpnlog"
    echo "  main-interface $slapos_ifname"
    echo "  interface $slapos_ifname"
    echo "  log $(cygpath -m /var/log/re6stnet)"
    echo -e "# $subnet\ntable 0\novpnlog" \
        "\nmain-interface $slapos_ifname\ninterface $slapos_ifname" \
        "\nlog $(cygpath -m /var/log/re6stnet)" \
        >> $re6stnet_configure_file
fi

# Run re6stnet if no native ipv6
if check_re6stnet_needed ; then
    check_re6stnet_configure || exit 1
    if [[ ! -r ${re6stnet_cgywin_script} ]] ; then
        cat <<EOF > /${re6stnet_cgywin_script}
$(cygpath -w /bin/bash.exe) --login -c 'python %*'
EOF
        chmod +x ${re6stnet_cgywin_script}
    fi
    
    if ! cygrunsrv --query $re6stnet_service_name >/dev/null 2>&1 ; then
        cygrunsrv -I $re6stnet_service_name -c $(dirname $re6stnet_configure_file) \
            -p $(which re6stnet) -a "@re6stnet.conf" -d "CYGWIN re6stnet" || \
            show_error_exit "Failed to install cygwin service $re6stnet_service_name."
    fi
    check_cygwin_service $re6stnet_service_name || exit 1
    echo "You can check log files in the /var/log/re6stnet/*.log"
else
    echo "Native IPv6 found, no re6stnet required."
fi

echo
echo Configure section re6stnet OK.
echo

# -----------------------------------------------------------
# taps: Install openvpn tap-windows drivers used by re6stnet
# -----------------------------------------------------------
# 
# Adding tap-windows driver will break others, so we add all drivers
# here. Get re6stnet client count, then remove extra drivers and add
# required drivers.
echo
echo Starting configure section taps ...
echo
original_connections=$(echo $(get_all_connections))
client_count=$(sed -n -e "s/^client-count *//p" $re6stnet_configure_file)
[[ -z $client_count ]] && client_count=10
echo "  Client count: $client_count"
re6stnet_name_list="re6stnet-tcp re6stnet-udp"
for (( i=1; i<=client_count; i=i+1 )) ; do
    re6stnet_name_list="$re6stnet_name_list re6stnet$i"
done
for name in $re6stnet_name_list ; do
    echo "Checking interface $name ..."
    if [[ ! " $original_connections " == *[\ ]$name[\ ]* ]] ; then
        echo "Installing  interface $name ..."
        ip vpntap add dev $name || \
            show_error_exit "Failed to install OpenVPN Tap-Windows Driver."
        echo "Interface $name installed."
    else
        echo "$name has been installed."
    fi
done
#
# Remove OpenVPN Tap-Windows Driver
#
# ip vpntap del dev re6stnet-x
#
echo
echo Configure section taps OK.
echo

# -----------------------------------------------------------
# runner: Create instance of slap web runner
# -----------------------------------------------------------
echo
echo Starting configure section runner ...
echo
slaprunner_title="SlapOS-Node-Runner-In-$computer_guid"
feature_code="#-*- SlapOS Web Runner JavaScript Boot Code -*-#"
if ! grep -q -F "$feature_code" $slapos_runner_file ; then
    echo Installing SlapOS Web Runner ...

    if [[ -r $re6stnet_configure_file ]] ; then
        re6stnet_ipv6=$(grep "Your subnet" $re6stnet_configure_file| \
            sed -e "s/^.*subnet: //g" -e "s/\/80 (CN.*\$/1/g")
        if [[ ! -z $re6stnet_ipv6 ]] ; then
            echo "Re6stnet address in this computer: $re6stnet_ipv6"
            netsh interface ipv6 show addr $slapos_ifname level=normal | \
                grep -q $re6stnet_ipv6 || \
                netsh interface ipv6 add addr $slapos_ifname $re6stnet_ipv6
        fi
    fi

    /opt/slapos/bin/slapos node format -cv --now || \
        show_error_exit "Failed to run slapos format."

    echo "Supply $slaprunner_cfg in the computer $computer_guid"
    /opt/slapos/bin/slapos supply  $slaprunner_cfg $computer_guid

    echo "Request an instance $slaprunner_title ..."
    patch_file=/etc/slapos/patches/slapos-cookbook-inotifyx.patch
    while true ; do
        /opt/slapos/bin/slapos node software --verbose
        # Apply patches to slapos.cookbook for inotifix
        if [[ -r $patch_file ]] ; then
            for x in $(find /opt/slapgrid/ -name slapos.cookbook-*.egg) ; do
                echo Apply patch $patch_file at $x
                cd $x
                patch -f --dry-run -p1 < $patch_file > /dev/null && \
                    patch -p1 < $patch_file
            done
        fi
        /opt/slapos/bin/slapos node instance --verbose
        /opt/slapos/bin/slapos node report --verbose
        /opt/slapos/bin/slapos request $client_config_file $slaprunner_title \
            $slaprunner_cfg --node computer_guid=$computer_guid && break
        sleep 3
    done
    # Connection parameters of instance are:
    #  {'backend_url': 'http://[2001:67c:1254:45::c5d5]:50000',
    #  'cloud9-url': 'http://localhost:9999',
    #  'password_recovery_code': 'e2d01c14',
    #  'ssh_command': 'ssh 2001:67c:1254:45::c5d5 -p 2222',
    #  'url': 'http://softinst39090.host.vifib.net/'}
    slaprunner_url=$(/opt/slapos/bin/slapos request $client_config_file \
        $slaprunner_title $slaprunner_cfg --node computer_guid=$computer_guid | \
        grep backend_url | sed -e "s/^.*': '//g" -e "s/',.*$//g")
    echo "SlapOS Web Runner URL: $slaprunner_url"
    [[ -z $slaprunner_url ]] && \
        show_error_exit "Failed to create instance of SlapOS Web Runner."

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
<!-- $feature_code -->
</html>
EOF
    echo SlapOS Web Runner boot file $slapos_runner_file generated.

    echo
    echo Install Web Runner OK.
    echo
fi
echo
echo Configure section runner OK.
echo

# -----------------------------------------------------------
# tab: Install cron service and create crontab
# -----------------------------------------------------------
echo
echo Starting configure section cron ...
echo
crontab_file="/var/cron/tabs/${USER}"
if [[ ! -r $crontab_file ]] ; then
    cat <<EOF  > $crontab_file
SHELL=/bin/bash
PATH=/usr/local/bin:/usr/bin:/usr/sbin:/sbin:/bin
MAILTO=""

# Run "Installation/Destruction of Software Releases" and "Deploy/Start/Stop Partitions" once per minute
* * * * * ${USER} /opt/slapos/bin/slapos node software --verbose --logfile=/opt/slapos/log/slapos-node-software.log > /dev/null 2>&1
* * * * * ${USER} /opt/slapos/bin/slapos node instance --verbose --logfile=/opt/slapos/log/slapos-node-instance.log > /dev/null 2>&1

# Run "Destroy Partitions to be destroyed" once per hour
0 * * * * ${USER} /opt/slapos/bin/slapos node report --maximal_delay=3600 --verbose --logfile=/opt/slapos/log/slapos-node-report.log > /dev/null 2>&1

# Run "Check/add IPs and so on" once per hour
0 * * * * ${USER} /opt/slapos/bin/slapos node format >> /opt/slapos/log/slapos-node-format.log 2>&1
EOF
fi
echo
echo
cat $crontab_file || show_error_exit "No crob tab found."
echo
echo 
if ps -ef | grep -q "/usr/sbin/cron" ; then
    echo "The cron job is running."
else
    echo Starting cron job ...
    /usr/sbin/cron &
    (( $? )) && show_error_exit "Failed to start cron job."
    disown -h
    echo "The cron job started."
fi
echo
echo Configure section cron OK.
echo

# -----------------------------------------------------------
# startup: Start slapos-configure when windows startup
# -----------------------------------------------------------
echo
echo Starting configure section startup ...
echo
slapos_run_script=$(cygpath -a $0)
regtool -q get "$slapos_run_key\\$slapos_run_entry" || \
    regtool -q set "$slapos_run_key\\$slapos_run_entry" \
    "\"$(cygpath -w /usr/bin/bash)\" --login -i $slapos_run_script" || \
    show_error_exit "Failed to add slapos-configure.sh as windows startup item."
echo "Windows startup item:"
echo "  $slapos_run_key\\$slapos_run_entry = " \
     $(regtool get "$slapos_run_key\\$slapos_run_entry")
echo
echo Configure section startup OK.
echo

echo Configure SlapOS successfully.
read -n 1 -t 60 -p "Press any key to exit..."
exit 0
