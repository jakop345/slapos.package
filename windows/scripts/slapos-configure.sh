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
#     * Create user slaproot who owns Administrator group rights
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
#        runner         Install web runner for this node
#
source $(/usr/bin/dirname $0)/slapos-include.sh

echo
echo Start slapos node configure ...
echo

if [[ ! ":$PATH" == :/opt/slapos/bin: ]] ; then
    for profile in ~/.bash_profile ~/.profile ; do
        grep -q "export PATH=/opt/slapos/bin:" $profile ||
        echo "export PATH=/opt/slapos/bin:\${PATH}" >> $profile
    done
fi

# cygrunsrv
# ssh-host-config
# syslog-ng-config
# openssl
# export WINDIR
# ipwin
# slapos_cron_config

# -----------------------------------------------------------
# Create paths
# -----------------------------------------------------------
mkdir -p /etc/opt/slapos/ssl/partition_pki
mkdir -p $slapos_client_home
mkdir -p /opt/slapos/log
mkdir -p /opt/download-cache
mkdir -p /opt/downloads
mkdir -p /etc/slapos/scripts
mkdir -p /etc/re6stnet

# -----------------------------------------------------------
# Create account: slaproot
# -----------------------------------------------------------
# Start seclogon service in the Windows XP
if csih_is_xp ; then
    echo "Set start property of seclogon to auto"
    sc config seclogon start= auto || 
    csih_warning "Warning: failed to set seclogon to auto start."
# In the later, it's RunAs service, and will start by default
fi

# echo Checking slapos account $slapos_admin ...
slapos_check_and_create_privileged_user $slapos_admin ||
csih_error "Failed to create account $slapos_admin."

# -----------------------------------------------------------
# Configure cygwin services: cygserver syslog-ng sshd
# -----------------------------------------------------------
echo
echo Starting configure cygwin services ...
echo
if ! cygrunsrv --query cygserver > /dev/null 2>&1 ; then
    echo Run cygserver-config ...
    /usr/bin/cygserver-config --yes || \
        csih_error "Failed to run cygserver-config"
else
    echo The cygserver service has been installed.
fi
check_cygwin_service cygserver

if ! cygrunsrv --query syslog-ng > /dev/null 2>&1 ; then
    echo Run syslog-ng-config ...
    /usr/bin/syslog-ng-config --yes || \
        csih_error "Failed to run syslog-ng-config"
else
    echo The syslog-ng service has been installed.
fi
check_cygwin_service syslog-ng

if ! cygrunsrv --query sshd > /dev/null 2>&1 ; then
    if csih_is_xp && [[ -z "${csih_PRIVILEGED_PASSWORD}" ]] ; then
        slapos_request_password $slapos_admin "Install sshd service need the password of $slapos_admin."
    fi
    echo Run ssh-host-config ...
    /usr/bin/ssh-host-config --yes --cygwin ntsec \
        --user $slapos_admin --pwd ${csih_PRIVILEGED_PASSWORD} ||
    csih_error "Failed to run ssh-host-config"
else
    echo The sshd service has been installed.
fi
check_cygwin_service sshd

# Use slapos-cron-config to configure slapos cron service. 
if ! cygrunsrv --query cron > /dev/null 2>&1 ; then
    [[ -x $slapos_cron_config ]] ||
    csih_error "Couldn't find slapos cron config script: $slapos_cron_config"

    if [[ -z "${csih_PRIVILEGED_PASSWORD}" ]] ; then
        slapos_request_password $slapos_admin "Install cron service need the password of $slapos_admin."
    fi

    echo Run slapos-cron-config ...
    $slapos_cron_config $slapos_admin ${csih_PRIVILEGED_PASSWORD} ||
    csih_error "Failed to run $slapos_cron_config"
else
    echo The cron service has been installed.
fi
check_cygwin_service cron

echo
echo Configure cygwin services OK.
echo

# -----------------------------------------------------------
# Install network connection used by slapos node
# -----------------------------------------------------------
echo
echo Starting configure slapos network ...
echo
if ! netsh interface ipv6 show interface | grep -q "\\b$slapos_ifname\\b" ; then
    echo Installing slapos network adapter ...
    ipwin install $WINDIR\\inf\\netloop.inf *msloop re6stnet-lo
fi
ip -4 addr add $ipv4_local_network dev $slapos_ifname
# reset_connection $slapos_ifname
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
    csih_error "Failed to install IPv6 protocol."
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
    csih_error "Failed to create template configure file."

sed -i -e "/^alias/,\$d" $client_template_file
echo "alias =
  apache_frontend http://git.erp5.org/gitweb/slapos.git/blob_plain/refs/heads/cygwin-share:/software/apache-frontend/software.cfg
  erp5 http://git.erp5.org/gitweb/slapos.git/blob_plain/refs/tags/slapos-0.143:/software/erp5/software.cfg
  mariadb http://git.erp5.org/gitweb/slapos.git/blob_plain/refs/heads/cygwin-share:/software/mariadb/software.cfg
  mysql http://git.erp5.org/gitweb/slapos.git/blob_plain/refs/heads/cygwin-share:/software/mysql-5.1/software.cfg
  slaposwebrunner http://git.erp5.org/gitweb/slapos.git/blob_plain/refs/heads/cygwin-share:/software/slaprunner-lite/software.cfg
  wordpress http://git.erp5.org/gitweb/slapos.git/blob_plain/refs/heads/cygwin-share:/software/wordpress/software.cfg
  netdrive_reporter http://git.erp5.org/gitweb/slapos.git/blob_plain/refs/heads/cygwin-share:/software/netdrive-reporter/software.cfg" \
  >> $client_template_file

if [[ ! -f $node_certificate_file ]] ; then
    read -p "Where is computer certificate file $(cygpath -w /computer.crt): " filename
    [[ -z "$filename" ]] && filename="/computer.crt"
    [[ ! -r "$filename" ]] && \
        csih_error "Computer certificate file $filename doesn't exists."
    echo "Copy certificate from $filename to $node_certificate_file"
    filename=$(cygpath -u $filename)
    cp $filename $node_certificate_file
else
    echo "Found computer certificate file: $node_certificate_file"
fi
openssl x509 -noout -in $node_certificate_file || \
    csih_error "Invalid computer certificate: $node_certificate_file."

if [[ ! -f $node_key_file ]] ; then
    read -p "Where is computer key file $(cygpath -w /computer.key): " filename
    [[ -z "$filename" ]] && filename="/computer.key"
    [[ ! -f "$filename" ]] && \
        csih_error "Key file $filename doesn't exists."
    echo "Copy key from $filename to $node_key_file"
    filename=$(cygpath -u $filename)
    cp $filename $node_key_file
else
    echo "Found computer key file: $node_key_file"
fi
openssl rsa -noout -in $node_key_file -check ||
csih_error "Invalid node key: $node_key_file."

if [[ ! -f $node_configure_file ]] ; then
    echo "Copy computer configure file from $node_template_file to $node_configure_file"
    cp $node_template_file $node_configure_file
fi

interface_guid=$(ipwin guid *msloop $slapos_ifname) ||
csih_error "Failed to get guid of interface: $slapos_ifname."
[[ "$interface_guid" == {*-*-*-*} ]] ||
csih_error "Invalid interface guid $interface_guid specified."

computer_guid=$(grep "CN=COMP" $node_certificate_file | \
    sed -e "s/^.*, CN=//g" | sed -e "s%/emailAddress.*\$%%g")
[[ "$computer_guid" == COMP-+([0-9]) ]] ||
csih_error "Invalid computer id '$computer_guid' specified."

echo "Computer configuration information:"
echo "  interface name:     $slapos_ifname"
echo "  GUID:               $interface_guid"
echo "  ipv4_local_network: $ipv4_local_network"
echo "  computer_id:        $computer_guid"
echo
echo "  If ipv4_local_network confilcts with your local network, change it"
echo "  in the file: $node_configure_file "
echo "  Or change it in the $(dirname $0)/slapos-include.sh"
echo "  and run Configure SlapOS again."

sed -i  -e "s%^\\s*interface_name.*$%interface_name = $interface_guid%" \
        -e "s%^#\?\\s*ipv6_interface.*$%# ipv6_interface =%g" \
        -e "s%^ipv4_local_network.*$%ipv4_local_network = $ipv4_local_network%" \
        -e "s%^computer_id.*$%computer_id = $computer_guid%" \
        $node_configure_file

if [[ ! -f $client_certificate_file ]] ; then
    read -p "Where is client certificate file $(cygpath -w /certificate): " filename
    [[ -z "$filename" ]] && filename="/certificate"
    [[ ! -f "$filename" ]] && \
        csih_error "Client certificate file $filename doesn't exists."
    echo "Copy client certificate from $filename to $client_certificate_file"
    filename=$(cygpath -u $filename)
    cp $filename $client_certificate_file
fi
openssl x509 -noout -in $client_certificate_file || \
    csih_error "Invalid client certificate: $client_certificate_file."

if [[ ! -f $client_key_file ]] ; then
    read -p "Where is client key file $(cygpath -w /key): " filename
    [[ -z "$filename" ]] && filename="/key"
    [[ ! -f "$filename" ]] && \
        csih_error "Key file $filename doesn't exists."
    echo "Copy client key from $filename to $client_key_file"
    filename=$(cygpath -u $filename)
    cp $filename $client_key_file
fi
openssl rsa -noout -in $client_key_file -check || \
    csih_error "Invalid client key: $client_key_file."

if [[ ! -f $client_configure_file ]] ; then
    echo "Copy client configure file from $client_template_file to $client_configure_file"
    cp $client_template_file $client_configure_file
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
    package=/opt/downloads/miniupnpc.tar.gz
    [[ -r $package ]] || csih_error "No package found: $package"
    echo "Installing miniupnpc ..."
    cd /opt
    tar xzf $package --no-same-owner
    mv $(ls -d miniupnpc-*) miniupnpc
    cd miniupnpc
    make
    python setup.py install || csih_error "Failed to install miniupnpc."
    echo "Install miniupnpc OK."
else
    echo Check miniupnpc OK.
fi

echo Checking pyOpenSSL ...
if [[ ! -d /opt/pyOpenSSL ]] ; then
    package=/opt/downloads/pyOpenSSL.tar.gz
    [[ -r $package ]] || csih_error "No package found: $package"
    echo "Installing pyOpenSSL ..."
    cd /opt
    tar xzf $package --no-same-owner
    mv $(ls -d pyOpenSSL-*) pyOpenSSL
    cd pyOpenSSL
    python setup.py install ||  csih_error "Failed ot install pyOpenSSL."
    echo "Install pyOpenSSL OK."
else
    echo Check pyOpenSSL OK.
fi

echo Checking re6stnet ...
if [[ ! -d /opt/re6stnet ]] ; then
    echo "Installing re6stnet ..."
    package=/opt/downloads/re6stnet.tar.gz
    cd /opt
    if [[ -r $package ]] ; then
        tar xzf $package --no-same-owner
        mv $(ls -d re6stnet-*) re6stnet
    else
        echo "Clone re6stnet from http://git.erp5.org/repos/re6stnet.git"
	git clone -b cygwin http://git.erp5.org/repos/re6stnet.git ||
        csih_error "Failed to clone re6stnet.git"
    fi
    cd re6stnet
    python setup.py install || csih_error "Failed to install re6stnet."
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
        csih_error "Register to nexedi re6stnet failed"
    [[ -r re6stnet.conf ]] || \
        csih_error "No $re6stnet_configure_file found."
    echo Register re6stnet OK.

    echo "Write information to re6stnet.conf:"
    echo "  # $subnet"
    echo "  table 0"
    echo "  ovpnlog"
    echo "  main-interface $slapos_ifname"
    echo "  interface $slapos_ifname"
    echo -e "# $subnet\ntable 0\novpnlog" \
        "\nmain-interface $slapos_ifname\ninterface $slapos_ifname" \
        >> $re6stnet_configure_file
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
if check_re6stnet_needed ; then
    client_count=$(sed -n -e "s/^client-count *//p" $re6stnet_configure_file)
    [[ -z "$client_count" ]] && client_count=10
    echo "Re6stnet client-count: $client_count"
    re6stnet_name_list="re6stnet-tcp re6stnet-udp"
    for (( i=1; i<=client_count; i=i+1 )) ; do
        re6stnet_name_list="$re6stnet_name_list re6stnet$i"
    done
    filename=$(cygpath -w $openvpn_tap_driver_inf)
    for name in $re6stnet_name_list ; do
        echo "Checking interface $name ..."
        if ! netsh interface ipv6 show interface | grep -q "\\b$name\\b" ; then
            [[ -r $openvpn_tap_driver_inf ]] ||
            csih_error "Failed to install OpenVPN Tap-Windows Driver, missing driver inf file: $filename"

            echo "Installing  interface $name ..."
            # ipwin install \"$filename\" $openvpn_tap_driver_hwid $name; ||
            ip vpntap add dev $name ||
            csih_error "Failed to install OpenVPN Tap-Windows Driver."
            echo "Interface $name installed."
        else
            echo "$name has been installed."
        fi
    done

    # Run re6stnet if no native ipv6
    check_re6stnet_configure ||
    csih_error "Failed to configure re6stnet."
    if ! cygrunsrv --query $re6stnet_service_name >/dev/null 2>&1 ; then
        if [[ -z "${csih_PRIVILEGED_PASSWORD}" ]] ; then
            slapos_request_password $slapos_admin "Install re6stnet service need the password of $slapos_admin."
        fi
        cygrunsrv -I $re6stnet_service_name -c $(dirname $re6stnet_configure_file) \
            -p $(which re6stnet) -a "@re6stnet.conf" -d "CYGWIN re6stnet" \
            -u $slapos_admin -w ${csih_PRIVILEGED_PASSWORD} ||
        csih_error "Failed to install $re6stnet_service_name service."
    fi
    echo "You can check log files in the /var/log/re6stnet/*.log"
    if ! check_cygwin_service $re6stnet_service_name ; then
        csih_inform "Service $re6stnet_service_name is not running. One possible case"
        csih_inform "is that re6stnet service is shutdown in unusual ways, in this case"
        csih_inform "you can fix it by removing '/var/lib/re6stnet'."
        if csih_request "Do you want to let me remove it for you?" ; then
            rm -rf /var/lib/re6stnet
        fi
        check_cygwin_service $re6stnet_service_name ||
        csih_error "Failed to start $re6stnet_service_name service."
    fi
else
    echo "Native IPv6 found, no taps required."
fi

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
if ! grep -q -F "$feature_code" $slaprunner_startup_file ; then
    echo Installing SlapOS Web Runner ...

    if [[ -r $re6stnet_configure_file ]] ; then
        re6stnet_ipv6=$(grep "Your subnet" $re6stnet_configure_file| \
            sed -e "s/^.*subnet: //g" -e "s/\/80 (CN.*\$/1/g")
        if [[ ! -z "$re6stnet_ipv6" ]] ; then
            echo "Re6stnet address in this computer: $re6stnet_ipv6"
            netsh interface ipv6 show addr $slapos_ifname level=normal | \
                grep -q $re6stnet_ipv6 || \
                netsh interface ipv6 add addr $slapos_ifname $re6stnet_ipv6
        fi
    fi

    /opt/slapos/bin/slapos node format -cv --now || \
        csih_error "Failed to run slapos format."

    echo "Supply slapwebrunner in the computer $computer_guid"
    /opt/slapos/bin/slapos supply slaposwebrunner $computer_guid

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
            slaposwebrunner --node computer_guid=$computer_guid && break
        sleep 3
    done
    # Connection parameters of instance are:
    #  {'backend_url': 'http://[2001:67c:1254:45::c5d5]:50000',
    #  'cloud9-url': 'http://localhost:9999',
    #  'password_recovery_code': 'e2d01c14',
    #  'ssh_command': 'ssh 2001:67c:1254:45::c5d5 -p 2222',
    #  'url': 'http://softinst39090.host.vifib.net/'}
    slaprunner_url=$(/opt/slapos/bin/slapos request $client_config_file \
        $slaprunner_title slaposwebrunner --node computer_guid=$computer_guid | \
        grep backend_url | sed -e "s/^.*': '//g" -e "s/',.*$//g")
    echo "SlapOS Web Runner URL: $slaprunner_url"
    [[ -z "$slaprunner_url" ]] && \
        csih_error "Failed to create instance of SlapOS Web Runner."

    cat <<EOF > $slaprunner_startup_file
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
    echo SlapOS Web Runner boot file $slaprunner_startup_file generated.

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
cron_user=$slapos_admin
slapos_crontab_file="/var/cron/tabs/$cron_user"
if [[ ! -f $slapos_crontab_file ]] ; then
    cat <<EOF  > $slapos_crontab_file
SHELL=/bin/bash
PATH=/usr/local/bin:/usr/bin:/usr/sbin:/sbin:/bin
MAILTO=""

# Run "Installation/Destruction of Software Releases" and "Deploy/Start/Stop Partitions" once per minute
* * * * * /opt/slapos/bin/slapos node software --verbose --logfile=/opt/slapos/log/slapos-node-software.log > /dev/null 2>&1
* * * * * /opt/slapos/bin/slapos node instance --verbose --logfile=/opt/slapos/log/slapos-node-instance.log > /dev/null 2>&1

# Run "Destroy Partitions to be destroyed" once per hour
0 * * * * /opt/slapos/bin/slapos node report --maximal_delay=3600 --verbose --logfile=/opt/slapos/log/slapos-node-report.log > /dev/null 2>&1

# Run "Check/add IPs and so on" once per hour
0 * * * * /opt/slapos/bin/slapos node format >> /opt/slapos/log/slapos-node-format.log 2>&1
EOF
fi
echo Change owner of $slapos_crontab_file to $cron_user
chown $cron_user $slapos_crontab_file
echo Change mode of $slapos_crontab_file to 644
chmod 644 $slapos_crontab_file
ls -l $slapos_crontab_file

echo
echo Begin of crontab of $slapos_admin:
echo ------------------------------------------------------------
cat $slapos_crontab_file || csih_error "No crob tab found."
echo ------------------------------------------------------------
echo End of crontab of $slapos_admin.

echo 
echo Configure section cron OK.
echo

# -----------------------------------------------------------
# startup: Start slapos-configure when windows startup
# -----------------------------------------------------------
# echo
# echo Starting configure section startup ...
# echo
# slapos_run_script=$(cygpath -a $0)
# regtool -q get "$slapos_run_key\\$slapos_run_entry" || \
#     regtool -q set "$slapos_run_key\\$slapos_run_entry" \
#     "\"$(cygpath -w /usr/bin/bash)\" --login -i $slapos_run_script" || \
#     csih_error "Failed to add slapos-configure.sh as windows startup item."
# echo "Windows startup item:"
# echo "  $slapos_run_key\\$slapos_run_entry = " \
#      $(regtool get "$slapos_run_key\\$slapos_run_entry")
# echo
# echo Configure section startup OK.
# echo

echo Configure SlapOS successfully.
read -n 1 -t 60 -p "Press any key to exit..."
exit 0
