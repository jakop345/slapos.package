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
    echo "        -P, --password=XXX password of slapos administrator"
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
declare _administrator=${slapos_administrator}
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
csih_check_program_or_error /usr/bin/slapos-cron-config slapos-patches
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
    csih_inform "Set start property of seclogon to auto"
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
csih_inform "Starting configure cygwin services ..."
if ! cygrunsrv --query ${cygserver_service_name} > /dev/null 2>&1 ; then
    csih_inform "run cygserver-config ..."
    /usr/bin/cygserver-config --yes || \
        csih_error "failed to run cygserver-config"
    [[ ${cygserver_service_name} == cygserver ]] ||
    cygrunsrv -I ${cygserver_service_name} -d "CYGWIN ${cygserver_service_name}" -p /usr/sbin/cygserver ||
    csih_error "failed to install service ${cygserver_service_name}"
else
    csih_inform "the cygserver service has been installed"
fi
check_cygwin_service ${cygserver_service_name}

if ! cygrunsrv --query ${syslog_service_name} > /dev/null 2>&1 ; then
    csih_inform "run syslog-ng-config ..."
    /usr/bin/syslog-ng-config --yes || \
        csih_error "failed to run syslog-ng-config"
    [[ ${syslog_service_name} == "syslog-ng" ]] ||
    cygrunsrv -I ${syslog_service_name} -d "CYGWIN ${syslog_service_name}" -p /usr/sbin/syslog-ng -a "-F" ||
    csih_error "failed to install service ${syslog_service_name}"

else
    csih_inform "the syslog-ng service has been installed"
fi
check_cygwin_service ${syslog_service_name}

if ! cygrunsrv --query ${sshd_service_name} > /dev/null 2>&1 ; then
    if csih_is_vista && [[ -z "${csih_PRIVILEGED_PASSWORD}" ]] ; then
        slapos_request_password ${_administrator} "Install sshd service need the password of ${_administrator}."
    fi
    csih_inform "run ssh-host-config ..."
    /usr/bin/ssh-host-config --yes --cygwin ntsec --port 22002 \
        --user ${_administrator} --pwd ${csih_PRIVILEGED_PASSWORD} ||
    csih_error "Failed to run ssh-host-config"
    if csih_is_vista ; then
        [[ ${sshd_service_name} == "sshd" ]] ||
        cygrunsrv -I ${sshd_service_name} -d "CYGWIN ${sshd_service_name}" -p /usr/sbin/sshd \
            -a "-D" -y tcpip -e "CYGWIN=ntsec" -u "${_administrator}" -w "${csih_PRIVILEGED_PASSWORD}" ||
        csih_error "failed to install service ${sshd_service_name}"
    else
        [[ ${sshd_service_name} == "sshd" ]] ||
        cygrunsrv -I ${sshd_service_name} -d "CYGWIN ${sshd_service_name}" -p /usr/sbin/sshd \
            -a "-D" -y tcpip -e "CYGWIN=ntsec" ||
        csih_error "failed to install service ${sshd_service_name}"
    fi
else
    csih_inform "the sshd service has been installed"
fi
check_cygwin_service ${sshd_service_name}

# Use slapos-cron-config to configure slapos cron service.
if ! cygrunsrv --query ${cron_service_name} > /dev/null 2>&1 ; then
    [[ -x ${slapos_cron_config} ]] ||
    csih_error "Couldn't find slapos cron config script: ${slapos_cron_config}"

    if [[ -z "${csih_PRIVILEGED_PASSWORD}" ]] ; then
        slapos_request_password ${_administrator} "Install cron service need the password of ${_administrator}."
    fi

    csih_inform "run slapos-cron-config ..."
    ${slapos_cron_config} ${cron_service_name} ${_administrator} ${csih_PRIVILEGED_PASSWORD} ||
    csih_error "Failed to run ${slapos_cron_config}"
else
    csih_inform "the cron service has been installed"
fi
check_cygwin_service ${cron_service_name}

csih_inform "Configure cygwin services OK"
echo ""

# -----------------------------------------------------------
# Install network connection used by slapos node
# -----------------------------------------------------------
csih_inform "Starting configure slapos network ..."
if ! netsh interface ipv6 show interface | grep -q "\\b${slapos_ifname}\\b" ; then
    csih_inform "Installing network interface ${slapos_ifname} ..."
    ipwin install $WINDIR\\inf\\netloop.inf *msloop ${slapos_ifname} ||
    csih_error "install network interface ${slapos_ifname} failed"
fi
ip -4 addr add $(echo ${ipv4_local_network} | sed -e "s%\.0/%.1/%g") dev ${slapos_ifname} ||
csih_error "add ipv4 address failed"

csih_inform "Configure slapos network OK"
echo ""

# -----------------------------------------------------------
# Check IPv6 protocol, install it if it isn't installed
# -----------------------------------------------------------
csih_inform "Starting configure IPv6 protocol ..."
netsh interface ipv6 show interface > /dev/null || \
    netsh interface ipv6 install || \
    csih_error "install IPv6 protocol failed"

csih_inform "Configure IPv6 protocol OK"
echo ""

# -----------------------------------------------------------
# config: Generate slapos node and client configure file
# -----------------------------------------------------------
csih_inform "Starting configure slapos client and node ..."

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
    csih_inform "copy certificate from ${_filename} to ${node_certificate_file}"
    _filename=$(cygpath -u ${_filename})
    cp ${_filename} ${node_certificate_file}
else
    csih_inform "found computer certificate file: ${node_certificate_file}"
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
    csih_inform "copy key from ${_filename} to ${node_key_file}"
    _filename=$(cygpath -u ${_filename})
    cp ${_filename} ${node_key_file}
else
    csih_inform "found computer key file: ${node_key_file}"
fi
openssl rsa -noout -in ${node_key_file} -check ||
csih_error "Invalid node key: ${node_key_file}."

if [[ ! -f ${node_configure_file} ]] ; then
    csih_inform "copy computer configure file from ${node_template_file} to ${node_configure_file}"
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

csih_inform "Computer configuration information:"
csih_inform "  interface name:     ${slapos_ifname}"
csih_inform "  GUID:               ${interface_guid}"
csih_inform "  ipv4_local_network: ${ipv4_local_network}"
csih_inform "  computer_id:        ${computer_guid}"
csih_inform "  user_base_name:     ${slapos_user_basename}"
csih_inform
csih_inform "  If ipv4_local_network confilcts with your local network, change it"
csih_inform "  in the file: ${node_configure_file} "
csih_inform "  Or change it in the $(dirname $0)/slapos-include.sh"
csih_inform "  and run Configure SlapOS again."

sed -i  -e "s%^\\s*interface_name.*$%interface_name = $interface_guid%" \
        -e "s%^#\?\\s*ipv6_interface.*$%# ipv6_interface =%g" \
        -e "s%^ipv4_local_network.*$%ipv4_local_network = $ipv4_local_network%" \
        -e "s%^computer_id.*$%computer_id = $computer_guid%" \
        -e "s%^user_base_name =.*$%user_base_name = ${slapos_user_basename}%" \
        ${node_configure_file}

if [[ ! -f ${client_certificate_file} ]] ; then
    _filename=${_client_certificate}
    [[ -z "${_filename}" ]] &&
    read -p "Where is client certificate file $(cygpath -w /certificate): " _filename
    [[ -z "${_filename}" ]] && _filename="/certificate"
    [[ ! -f "${_filename}" ]] && \
        csih_error "Client certificate file ${_filename} doesn't exists."
    csih_inform "copy client certificate from ${_filename} to ${client_certificate_file}"
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
    csih_inform "copy client key from ${_filename} to ${client_key_file}"
    _filename=$(cygpath -u ${_filename})
    cp ${_filename} ${client_key_file}
fi
openssl rsa -noout -in ${client_key_file} -check || \
    csih_error "Invalid client key: ${client_key_file}."

if [[ ! -f ${client_configure_file} ]] ; then
    csih_inform "copy client configure file from ${client_template_file} to ${client_configure_file}"
    cp ${client_template_file} ${client_configure_file}
fi

csih_inform "Client configuration information:"
csih_inform "   client certificate file: ${client_certificate_file}"
csih_inform "   client key file:         ${client_key_file}"
sed -i -e "s%^cert_file.*$%cert_file = ${client_certificate_file}%" \
       -e "s%^key_file.*$%key_file = ${client_key_file}%" \
       ${client_configure_file}

csih_inform "Configure slapos client and node OK"
echo ""

# -----------------------------------------------------------
# re6stnet: Install required packages and register to nexedi
# -----------------------------------------------------------
csih_inform "Starting configure section re6stnet ..."

csih_inform "checking miniupnpc ..."
if [[ ! -d /opt/miniupnpc ]] ; then
    _filename=/opt/downloads/miniupnpc.tar.gz
    [[ -r ${_filename} ]] || csih_error "No package found: ${_filename}"
    csih_inform "installing miniupnpc ..."
    cd /opt
    tar xzf ${_filename} --no-same-owner
    mv $(ls -d miniupnpc-*) miniupnpc
    cd miniupnpc
    make
    python setup.py install || csih_error "Failed to install miniupnpc."
    csih_inform "install miniupnpc OK"
else
    csih_inform "check miniupnpc OK"
fi

csih_inform "checking pyOpenSSL ..."
if [[ ! -d /opt/pyOpenSSL ]] ; then
    _filename=/opt/downloads/pyOpenSSL.tar.gz
    [[ -r ${_filename} ]] || csih_error "No package found: ${_filename}"
    csih_inform "installing pyOpenSSL ..."
    cd /opt
    tar xzf ${_filename} --no-same-owner
    mv $(ls -d pyOpenSSL-*) pyOpenSSL
    cd pyOpenSSL
    python setup.py install ||  csih_error "Failed ot install pyOpenSSL."
    csih_inform "install pyOpenSSL OK"
else
    csih_inform "check pyOpenSSL OK"
fi

echo Checking re6stnet ...
if [[ ! -d /opt/re6stnet ]] ; then
    csih_inform "installing re6stnet ..."
    _filename=/opt/downloads/re6stnet.tar.gz
    cd /opt
    if [[ -r ${_filename} ]] ; then
        tar xzf ${_filename} --no-same-owner
        mv $(ls -d re6stnet-*) re6stnet
    else
        csih_inform "clone re6stnet from http://git.erp5.org/repos/re6stnet.git"
	git clone -b cygwin http://git.erp5.org/repos/re6stnet.git ||
        csih_error "Failed to clone re6stnet.git"
    fi
    cd re6stnet
    python setup.py install || csih_error "Failed to install re6stnet."
    csih_inform "install re6stnet OK"
else
    csih_inform "check re6stnet OK"
fi

csih_inform "checking re6stnet configuration ..."
if [[ ! -r ${re6stnet_configure_file} ]] ; then
    csih_inform "registering to http://re6stnet.nexedi.com ..."
    cd $(dirname ${re6stnet_configure_file})
    # Your subnet: 2001:67c:1254:e:19::/80 (CN=917529/32)
    subnet=$(re6st-conf --registry http://re6stnet.nexedi.com/ --anonymous | \
        grep "^Your subnet:") || \
        csih_error "Register to nexedi re6stnet failed"
    [[ -r re6stnet.conf ]] || \
        csih_error "No ${re6stnet_configure_file} found."
    csih_inform "register re6stnet OK"

    csih_inform "Write information to re6stnet.conf:"
    csih_inform "  # $subnet"
    csih_inform "  table 0"
    csih_inform "  ovpnlog"
    csih_inform "  main-interface ${slapos_ifname}"
    csih_inform "  interface ${slapos_ifname}"
    echo -e "# $subnet\ntable 0\novpnlog" \
        "\nmain-interface ${slapos_ifname}\ninterface ${slapos_ifname}" \
        >> ${re6stnet_configure_file}
fi

csih_inform "Configure section re6stnet OK"
echo ""

# -----------------------------------------------------------
# taps: Install openvpn tap-windows drivers used by re6stnet
# -----------------------------------------------------------
#
# Adding tap-windows driver will break others, so we add all drivers
# here. Get re6stnet client count, then remove extra drivers and add
# required drivers.
csih_inform "Starting configure section taps ..."

if check_re6stnet_needed ; then
    csih_inform "Disable IPv6 6to4 interface ... "
    netsh interface ipv6 6to4 set state disable && csih_inform "OK."
    csih_inform "Disable IPv6 isatap interface ... "
    netsh interface ipv6 isatap set state disable && csih_inform "OK."
    csih_inform "Disable IPv6 teredo interface ... "
    netsh interface teredo set state disable && csih_inform "OK."

    _count=$(sed -n -e "s/^client-count *//p" ${re6stnet_configure_file})
    [[ -z "${_count}" ]] && _count=10
    csih_inform "re6stnet client-count: ${_count}"
    _name_list="re6stnet-tcp re6stnet-udp"
    for (( i=1; i<=${_count}; i=i+1 )) ; do
        _name_list="${_name_list} re6stnet$i"
    done
    _filename=$(cygpath -w ${openvpn_tap_driver_inf})
    for _name in ${_name_list} ; do
        csih_inform "checking interface ${_name} ..."
        if ! netsh interface ipv6 show interface | grep -q "\\b${_name}\\b" ; then
            [[ -r ${openvpn_tap_driver_inf} ]] ||
            csih_error "Failed to install OpenVPN Tap-Windows Driver, missing driver inf file: ${_filename}"

            csih_inform "installing  interface ${_name} ..."
            # ipwin install \"${_filename}\" $openvpn_tap_driver_hwid ${_name}; ||
            ip vpntap add dev ${_name} ||
            csih_error "Failed to install OpenVPN Tap-Windows Driver."
            csih_inform "interface ${_name} installed."
        else
            csih_inform "${_name} has been installed."
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
    csih_inform "you can check log files in the /var/log/re6stnet/*.log"
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
    csih_request "native IPv6 found, no taps required."
fi

csih_inform "Configure section taps OK"
echo ""

# -----------------------------------------------------------
# tab: Install cron service and create crontab
# -----------------------------------------------------------
csih_inform "Starting configure section cron ..."

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

csih_inform "change owner of ${_crontab_file} to ${_cron_user}"
chown ${_cron_user} ${_crontab_file}

csih_inform "change mode of ${_crontab_file} to 644"
chmod 644 ${_crontab_file}
ls -l ${_crontab_file}

csih_inform "begin of crontab of ${_administrator}:"
csih_inform "************************************************************"
cat ${_crontab_file} || csih_error "No crob tab found."
csih_inform "************************************************************"
csih_inform "end of crontab of ${_administrator}"

csih_inform "Configure section cron OK"
echo ""

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

echo ""
csih_inform "Configure SlapOS successfully"
echo ""

read -n 1 -t 60 -p "Press any key to exit..."
exit 0
