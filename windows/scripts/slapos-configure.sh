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
function show_usage()
{
    echo ""
    echo "Usage:"
    echo ""
    echo "    ./slapos-configure [options] [action] [configure item]"
    echo ""
    echo "    Availabe options:"
    echo ""
    echo "        -U, --user=XXX     slapos administrator, default is slaproot"
    echo "        -P, --password=XXX password of administrator"
    echo ""
    echo "        --computer-certificate=FILENAME"
    echo "        --computer-key=FILENAME"
    echo "        --client-certificate=FILENAME"
    echo "        --client-key=FILENAME"
    echo ""
    echo "    The action option:"
    echo ""
    echo "        --install      Install only when the item hasn't been installed"
    echo "        --query        Interactive to install all the item"
    echo "        --overwite     Overwrite the item even it has been installed"
    echo "        --uninstall    Remove the configure item"
    echo ""
    echo "    Default is --install"
    echo ""
    echo "    The configure item option:"
    echo ""
    echo "        *              All the configure item"
    echo "        re6stnet       Install re6stent and dependencies"
    echo "        taps           Install OpenVPN Tap-Windows Driver for re6stnet"
    echo "        config         Generate slapos node and client configure files"
    echo "        cron           Generate cron file and start cron job"
    echo ""
}

source $(/usr/bin/dirname $0)/slapos-include.sh
csih_inform "Start slapos node configure ..."
echo ""

# -----------------------------------------------------------
# Local variable
# -----------------------------------------------------------
declare _administrator=${slapos_user}
declare _password=
declare _computer_certificate=
declare _computer_key=
declare _client_certificate=
declare _client_key=

# -----------------------------------------------------------
# Command line options
# -----------------------------------------------------------
while test $# -gt 0; do
    # Normalize the prefix.
    case "$1" in
    -*=*) optarg=`echo "$1" | sed 's/[-_a-zA-Z0-9]*=//'` ;;
    *) optarg= ;;
    esac

    case "$1" in
    --password=*)
    _password=$optarg
    ;;
    -P)
    _password=$2
    shift
    ;;
    --user=*)
    _administrator=$optarg
    ;;
    -P)
    _administrator=$2
    shift
    ;;
    --computer-certificate=*)
    _computer_certificate=$optarg
    ;;
    --computer-key=*)
    _computer_key=$optarg
    ;;
    --client-certificate=*)
    _client_certificate=$optarg
    ;;
    --client-key=*)
    _client_key=$optarg
    ;;
    *)
    show_usage
    exit 1
    ;;
    esac

    # Next please.
    shift
done

# -----------------------------------------------------------
# Check and configure cygwin environments
# -----------------------------------------------------------
if [[ ! ":$PATH" == :/opt/slapos/bin: ]] ; then
    for profile in ~/.bash_profile ~/.profile ; do
        ! grep -q "export PATH=/opt/slapos/bin:" $profile &&
        csih_inform "add /opt/slapos/bin to PATH" &&
        echo "export PATH=/opt/slapos/bin:\${PATH}" >> $profile
    done
fi

csih_check_program_or_error /usr/bin/cygrunsrv cygserver
csih_check_program_or_error /usr/bin/ssh-host-config ssh
csih_check_program_or_error /usr/bin/syslog-ng-config syslog-ng
csih_check_program_or_error /usr/bin/openssl openssl
csih_check_program_or_error /usr/bin/ipwin slapos-patches
csih_check_program_or_error /usr/bin/slapos_cron_config slapos-patches
[[ -z "$WINDIR" ]] && csih_error "missing environment variable WINDIR"

# -----------------------------------------------------------
# Create paths
# -----------------------------------------------------------
mkdir -p /etc/opt/slapos/ssl/partition_pki
mkdir -p ${slapos_client_home}
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
    csih_warning "failed to set seclogon to auto start."
# In the later, it's RunAs service, and will start by default
fi

# echo Checking slapos account ${_administrator} ...
slapos_check_and_create_privileged_user ${_administrator} ${_password} ||
csih_error "failed to create account ${_administrator}."

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
        slapos_request_password ${_administrator} "Install sshd service need the password of ${_administrator}."
    fi
    echo Run ssh-host-config ...
    /usr/bin/ssh-host-config --yes --cygwin ntsec --port 22002 \
        --user ${_administrator} --pwd ${csih_PRIVILEGED_PASSWORD} ||
    csih_error "Failed to run ssh-host-config"
else
    echo The sshd service has been installed.
fi
check_cygwin_service sshd

# Use slapos-cron-config to configure slapos cron service.
if ! cygrunsrv --query cron > /dev/null 2>&1 ; then
    [[ -x ${slapos_cron_config} ]] ||
    csih_error "Couldn't find slapos cron config script: ${slapos_cron_config}"

    if [[ -z "${csih_PRIVILEGED_PASSWORD}" ]] ; then
        slapos_request_password ${_administrator} "Install cron service need the password of ${_administrator}."
    fi

    echo Run slapos-cron-config ...
    ${slapos_cron_config} ${_administrator} ${csih_PRIVILEGED_PASSWORD} ||
    csih_error "Failed to run ${slapos_cron_config}"
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
if ! netsh interface ipv6 show interface | grep -q "\\b${slapos_ifname}\\b" ; then
    echo Installing slapos network adapter ...
    ipwin install $WINDIR\\inf\\netloop.inf *msloop ${slapos_ifname}
fi
ip -4 addr add $(echo ${ipv4_local_network} | sed -e "s%\.0/%.1/%g") dev ${slapos_ifname}
# reset_connection ${slapos_ifname}
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
[[ -r ${node_template_file} && -r ${client_template_file} ]] || \
    create_template_configure_file || \
    csih_error "Failed to create template configure file."

sed -i -e "/^alias/,\$d" ${client_template_file}
echo "alias =
  apache_frontend http://git.erp5.org/gitweb/slapos.git/blob_plain/refs/heads/cygwin-share:/software/apache-frontend/software.cfg
  erp5 http://git.erp5.org/gitweb/slapos.git/blob_plain/refs/tags/slapos-0.143:/software/erp5/software.cfg
  mariadb http://git.erp5.org/gitweb/slapos.git/blob_plain/refs/heads/cygwin-share:/software/mariadb/software.cfg
  mysql http://git.erp5.org/gitweb/slapos.git/blob_plain/refs/heads/cygwin-share:/software/mysql-5.1/software.cfg
  slaposwebrunner http://git.erp5.org/gitweb/slapos.git/blob_plain/refs/heads/cygwin-share:/software/slaprunner-lite/software.cfg
  wordpress http://git.erp5.org/gitweb/slapos.git/blob_plain/refs/heads/cygwin-share:/software/wordpress/software.cfg
  netdrive_reporter http://git.erp5.org/gitweb/slapos.git/blob_plain/refs/heads/cygwin-share:/software/netdrive-reporter/software.cfg" \
  >> ${client_template_file}

if [[ ! -f ${node_certificate_file} ]] ; then
    _filename=${_computer_certificate}
    [[ -z "${_filename}" ]] &&
    read -p "Where is computer certificate file $(cygpath -w /computer.crt): " _filename
    [[ -z "${_filename}" ]] && _filename="/computer.crt"
    [[ ! -r "${_filename}" ]] && \
        csih_error "Computer certificate file ${_filename} doesn't exists."
    echo "Copy certificate from ${_filename} to ${node_certificate_file}"
    _filename=$(cygpath -u ${_filename})
    cp ${_filename} ${node_certificate_file}
else
    echo "Found computer certificate file: ${node_certificate_file}"
fi
openssl x509 -noout -in ${node_certificate_file} || \
    csih_error "Invalid computer certificate: ${node_certificate_file}."

if [[ ! -f ${node_key_file} ]] ; then
    _filename=${_computer_key}
    [[ -z "${_filename}" ]] &&
    read -p "Where is computer key file $(cygpath -w /computer.key): " _filename
    [[ -z "${_filename}" ]] && _filename="/computer.key"
    [[ ! -f "${_filename}" ]] && \
        csih_error "Key file ${_filename} doesn't exists."
    echo "Copy key from ${_filename} to ${node_key_file}"
    _filename=$(cygpath -u ${_filename})
    cp ${_filename} ${node_key_file}
else
    echo "Found computer key file: ${node_key_file}"
fi
openssl rsa -noout -in ${node_key_file} -check ||
csih_error "Invalid node key: ${node_key_file}."

if [[ ! -f ${node_configure_file} ]] ; then
    echo "Copy computer configure file from ${node_template_file} to ${node_configure_file}"
    cp ${node_template_file} ${node_configure_file}
fi

interface_guid=$(ipwin guid *msloop ${slapos_ifname}) ||
csih_error "Failed to get guid of interface: ${slapos_ifname}."
[[ "$interface_guid" == {*-*-*-*} ]] ||
csih_error "Invalid interface guid $interface_guid specified."

computer_guid=$(grep "CN=COMP" ${node_certificate_file} | \
    sed -e "s/^.*, CN=//g" | sed -e "s%/emailAddress.*\$%%g")
[[ "$computer_guid" == COMP-+([0-9]) ]] ||
csih_error "Invalid computer id '$computer_guid' specified."

echo "Computer configuration information:"
echo "  interface name:     ${slapos_ifname}"
echo "  GUID:               $interface_guid"
echo "  ipv4_local_network: $ipv4_local_network"
echo "  computer_id:        $computer_guid"
echo
echo "  If ipv4_local_network confilcts with your local network, change it"
echo "  in the file: ${node_configure_file} "
echo "  Or change it in the $(dirname $0)/slapos-include.sh"
echo "  and run Configure SlapOS again."

sed -i  -e "s%^\\s*interface_name.*$%interface_name = $interface_guid%" \
        -e "s%^#\?\\s*ipv6_interface.*$%# ipv6_interface =%g" \
        -e "s%^ipv4_local_network.*$%ipv4_local_network = $ipv4_local_network%" \
        -e "s%^computer_id.*$%computer_id = $computer_guid%" \
        ${node_configure_file}

if [[ ! -f ${client_certificate_file} ]] ; then
    _filename=${_client_certificate}
    [[ -z "${_filename}" ]] &&
    read -p "Where is client certificate file $(cygpath -w /certificate): " _filename
    [[ -z "${_filename}" ]] && _filename="/certificate"
    [[ ! -f "${_filename}" ]] && \
        csih_error "Client certificate file ${_filename} doesn't exists."
    echo "Copy client certificate from ${_filename} to ${client_certificate_file}"
    _filename=$(cygpath -u ${_filename})
    cp ${_filename} ${client_certificate_file}
fi
openssl x509 -noout -in ${client_certificate_file} || \
    csih_error "Invalid client certificate: ${client_certificate_file}."

if [[ ! -f ${client_key_file} ]] ; then
    _filename=${_client_key}
    [[ -z "${_filename}" ]] &&
    read -p "Where is client key file $(cygpath -w /key): " _filename
    [[ -z "${_filename}" ]] && _filename="/key"
    [[ ! -f "${_filename}" ]] && \
        csih_error "Key file ${_filename} doesn't exists."
    echo "Copy client key from ${_filename} to ${client_key_file}"
    _filename=$(cygpath -u ${_filename})
    cp ${_filename} ${client_key_file}
fi
openssl rsa -noout -in ${client_key_file} -check || \
    csih_error "Invalid client key: ${client_key_file}."

if [[ ! -f ${client_configure_file} ]] ; then
    echo "Copy client configure file from ${client_template_file} to ${client_configure_file}"
    cp ${client_template_file} ${client_configure_file}
fi

echo "Client configuration information:"
echo "   client certificate file: ${client_certificate_file}"
echo "   client key file:         ${client_key_file}"
sed -i -e "s%^cert_file.*$%cert_file = ${client_certificate_file}%" \
       -e "s%^key_file.*$%key_file = ${client_key_file}%" \
       ${client_configure_file}
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
    _filename=/opt/downloads/miniupnpc.tar.gz
    [[ -r ${_filename} ]] || csih_error "No package found: ${_filename}"
    echo "Installing miniupnpc ..."
    cd /opt
    tar xzf ${_filename} --no-same-owner
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
    _filename=/opt/downloads/pyOpenSSL.tar.gz
    [[ -r ${_filename} ]] || csih_error "No package found: ${_filename}"
    echo "Installing pyOpenSSL ..."
    cd /opt
    tar xzf ${_filename} --no-same-owner
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
    _filename=/opt/downloads/re6stnet.tar.gz
    cd /opt
    if [[ -r ${_filename} ]] ; then
        tar xzf ${_filename} --no-same-owner
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
if [[ ! -r ${re6stnet_configure_file} ]] ; then
    echo "Registering to http://re6stnet.nexedi.com ..."
    cd $(dirname ${re6stnet_configure_file})
    # Your subnet: 2001:67c:1254:e:19::/80 (CN=917529/32)
    subnet=$(re6st-conf --registry http://re6stnet.nexedi.com/ --anonymous | \
        grep "^Your subnet:") || \
        csih_error "Register to nexedi re6stnet failed"
    [[ -r re6stnet.conf ]] || \
        csih_error "No ${re6stnet_configure_file} found."
    echo Register re6stnet OK.

    echo "Write information to re6stnet.conf:"
    echo "  # $subnet"
    echo "  table 0"
    echo "  ovpnlog"
    echo "  main-interface ${slapos_ifname}"
    echo "  interface ${slapos_ifname}"
    echo -e "# $subnet\ntable 0\novpnlog" \
        "\nmain-interface ${slapos_ifname}\ninterface ${slapos_ifname}" \
        >> ${re6stnet_configure_file}
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
    csih_inform "Disable IPv6 6to4 interface ... "
    netsh interface ipv6 6to4 set state disable && csih_inform "OK."
    csih_inform "Disable IPv6 isatap interface ... "
    netsh interface ipv6 isatap set state disable && csih_inform "OK."
    csih_inform "Disable IPv6 teredo interface ... "
    netsh interface teredo set state disable && csih_inform "OK."

    _count=$(sed -n -e "s/^client-count *//p" ${re6stnet_configure_file})
    [[ -z "${_count}" ]] && _count=10
    echo "Re6stnet client-count: ${_count}"
    _name_list="re6stnet-tcp re6stnet-udp"
    for (( i=1; i<=${_count}; i=i+1 )) ; do
        _name_list="${_name_list} re6stnet$i"
    done
    _filename=$(cygpath -w ${openvpn_tap_driver_inf})
    for name in ${_name_list} ; do
        echo "Checking interface $name ..."
        if ! netsh interface ipv6 show interface | grep -q "\\b$name\\b" ; then
            [[ -r ${openvpn_tap_driver_inf} ]] ||
            csih_error "Failed to install OpenVPN Tap-Windows Driver, missing driver inf file: ${_filename}"

            echo "Installing  interface $name ..."
            # ipwin install \"${_filename}\" $openvpn_tap_driver_hwid $name; ||
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
    if ! cygrunsrv --query ${re6stnet_service_name} >/dev/null 2>&1 ; then
        if [[ -z "${csih_PRIVILEGED_PASSWORD}" ]] ; then
            slapos_request_password ${_administrator} "Install re6stnet service need the password of ${_administrator}."
        fi
        cygrunsrv -I ${re6stnet_service_name} -c $(dirname ${re6stnet_configure_file}) \
            -p $(which re6stnet) -a "@re6stnet.conf" -d "CYGWIN re6stnet" \
            -u ${_administrator} -w ${csih_PRIVILEGED_PASSWORD} ||
        csih_error "Failed to install ${re6stnet_service_name} service."
    fi
    echo "You can check log files in the /var/log/re6stnet/*.log"
    if ! check_cygwin_service ${re6stnet_service_name} ; then
        csih_inform "Service ${re6stnet_service_name} is not running. One possible case"
        csih_inform "is that re6stnet service is shutdown in unusual ways, in this case"
        csih_inform "you can fix it by removing '/var/lib/re6stnet'."
        if csih_request "Do you want to let me remove it for you?" ; then
            rm -rf /var/lib/re6stnet
        fi
        check_cygwin_service ${re6stnet_service_name} ||
        csih_error "Failed to start ${re6stnet_service_name} service."
    fi
else
    echo "Native IPv6 found, no taps required."
fi

echo
echo Configure section taps OK.
echo

# -----------------------------------------------------------
# tab: Install cron service and create crontab
# -----------------------------------------------------------
echo
echo Starting configure section cron ...
echo
_cron_user=${_administrator}
_crontab_file="/var/cron/tabs/${_cron_user}"
if [[ ! -f ${_crontab_file} ]] ; then
    cat <<EOF  > ${_crontab_file}
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
echo Change owner of ${_crontab_file} to ${_cron_user}
chown ${_cron_user} ${_crontab_file}
echo Change mode of ${_crontab_file} to 644
chmod 644 ${_crontab_file}
ls -l ${_crontab_file}

echo
echo Begin of crontab of ${_administrator}:
echo ------------------------------------------------------------
cat ${_crontab_file} || csih_error "No crob tab found."
echo ------------------------------------------------------------
echo End of crontab of ${_administrator}.

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
