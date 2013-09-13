#! /bin/bash
#
# This script need root rights. Before run it, make sure you have root
# right. In Windows 7 and later,, you can start terminal by clicking
# Run as Administrator, then run this script in this terminal.
#
# It used to configure slapos node, it could be run at anytime to
# check the configure of slapos node. The main functions:
#
#     * Create a super user who owns Administrator group rights
#
#     * re6stnet: Install re6stnet and register to nexedi re6stnet
#
#     * network: Install msloop network adapter for slapos node
#
#     * node: Create node configure file by ca/key
#
#     * client: Create client configure file by ca/key
#
#     * openvpn: Install openvpn and re6stnet service if required
#
#     * cron: Configure cron service if required
#
#     * slap-runner: Create slapos-webrunner instance in this node.
#
#     * test-agent: Create test-agent instance in this node.
#
# The use cases of slapos-configure.sh:
#
#    1. Configure slapos node after you have run slapos-cygwin-bootstrap.sh
#
#       ./slapos-configure.sh
#
#    2. Create slap-runner in your slapos node.
#
#       ./slapos-configure.sh slap-runner
#
#       You can run many times until it return OK.
#
#    3. Remove client configuration files
#
#       ./slapos-configure.sh --remove client
#
source $(/usr/bin/dirname $0)/slapos-include.sh

# ======================================================================
# Functions
# ======================================================================
function show_usage()
{
    echo ""
    echo "Usage:"
    echo ""
    echo "    ./slapos-configure.sh [options] [sections]"
    echo ""
    echo "    Availabe options:"
    echo ""
    echo "        -P, --password=XXX                "
    echo "        --computer-certificate=FILENAME"
    echo "        --computer-key=FILENAME"
    echo "        --client-certificate=FILENAME"
    echo "        --client-key=FILENAME"
    echo "        --ipv4-local-network=x.x.x.x/n"
    echo "        --ipv6-local-address=::"
    echo "        -f, --force                       Reinstall even the item has"
    echo "                                          been installed"
    echo "        -r, --remove                      Remove configuration sections"
    echo ""
    echo "    The configure items could be one or more of the following values:"
    echo ""
    echo "        client         Generate slapos client configure files"
    echo "        cron           Generate cron file and start cron job"
    echo "        network        Install msloop network connection for slapos"
    echo "        node           Generate slapos node configure files"
    echo "        openvpn        Install openvpn and re6stnet service"
    echo "        re6stnet       Install re6stnet and dependencies"
    echo "        runner         Create slap-runner instance"
    echo "        test-agent     Create test-agent instance"
    echo ""
    echo "    If no configure items specified, it will choose the following sections: "
    echo ""
    echo "      client will not be selected if nor --client-certificate and "
    echo "      --client-key specified "
    echo ""
    echo "      cron will always be selected"
    echo ""
    echo "      network will always be selected"
    echo ""
    echo "      node will always be selected"
    echo ""
    echo "      openvpn will not be selected if native IPv6 works"
    echo ""
    echo "      re6stnet will not be selected if --ipv6-local-address specified"
    echo ""
    echo "      runner will not be selected"
    echo ""
    echo "      test-agent will not be selected"
    echo ""
}
readonly -f show_usage

function configure_sanity_check()
{
    csih_check_program_or_error /usr/bin/cygrunsrv cygserver
    csih_check_program_or_error /usr/bin/syslog-ng-config syslog-ng
    csih_check_program_or_error /usr/sbin/cron cron

    csih_check_program_or_error /usr/bin/slapos-cron-config slapos-cywgin
    csih_check_program_or_error /usr/bin/ipwin slapos-cygwin
    csih_check_program_or_error /usr/bin/ip slapos-cygwin
    csih_check_program_or_error /usr/bin/useradd slapos-cygwin
    csih_check_program_or_error /usr/bin/usermod slapos-cygwin
    csih_check_program_or_error /usr/bin/regpwd slapos-cygwin
}
readonly -f configure_sanity_check

function configure_create_cygwin_service()
{
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
}
readonly -f configure_create_cygwin_service

function configure_section_re6stnet()
{
    csih_inform "checking miniupnpc ..."
    if [[ ! -d /opt/miniupnpc ]] ; then
        _filename=/opt/downloads/miniupnpc.tar.gz
        [[ -r ${_filename} ]] || 
        wget -c http://miniupnp.free.fr/files/download.php?file=miniupnpc-1.8.tar.gz -O ${_filename} ||
        csih_error "No package found: ${_filename}"
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
        [[ -r ${_filename} ]] || 
        wget -c --no-check-certificate https://pypi.python.org/packages/source/p/pyOpenSSL/pyOpenSSL-0.13.tar.gz#md5=767bca18a71178ca353dff9e10941929 -O ${_filename} ||
        csih_error "No package found: ${_filename}"
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

        _log_path=$(cygpath -m /var/log/re6stnet)
        csih_inform "Write information to re6stnet.conf:"
        csih_inform "  # $subnet"
        csih_inform "  table 0"
        csih_inform "  log ${_log_path}"
        csih_inform "  ovpnlog"
        csih_inform "  main-interface ${slapos_ifname}"
        csih_inform "  interface ${slapos_ifname}"
        echo -e "# $subnet\ntable 0\nlog ${_log_path}\novpnlog" \
            "\nmain-interface ${slapos_ifname}\ninterface ${slapos_ifname}" \
            >> ${re6stnet_configure_file}
    fi
}
readonly -f configure_section_re6stnet

function configure_section_network()
{
    if ! netsh interface ipv6 show interface | grep -q "\\b${slapos_ifname}\\b" ; then
        csih_inform "Installing network interface ${slapos_ifname} ..."
        ipwin install netloop.inf *msloop ${slapos_ifname} ||
        csih_error "install network interface ${slapos_ifname} failed"
    fi
    _addr4=$(echo ${_ipv4_local_network} | sed -e "s%\.0/%.1/%g")
    if [[ -n "${_addr}" ]] ; then
        netsh interface ip show addr ${slapos_ifname} | grep -q "${_addr4}" ||
        ip -4 addr add ${_addr4} dev ${slapos_ifname} ||
        csih_error "add ipv4 address failed"
    else
        csih_warning "No IPv4 address assigned to slapos network"
    fi

    if [[ -n "${_ipv6_local_address}" ]] ; then
        _addr6=${_ipv6_local_address}
    elif [[ -r ${re6stnet_configure_file} ]] ; then
        _addr6=$(grep "Your subnet" ${re6stnet_configure_file} | \
            sed -e "s/^.*subnet: //g" -e "s/\/80 (CN.*\$/1/g")
    fi
    if [[ -n "${_addr6}" ]] ; then
        csih_inform "IPv6 address for slapos network : ${_addr6}"
        netsh interface ipv6 show addr ${slapos_ifname} level=normal | \
            grep -q " ${_addr6}\$" || \
            netsh interface ipv6 add addr ${slapos_ifname} ${_addr6}
    else
        csih_warning "No IPv6 address assigned to slapos network"
    fi
}
readonly -f configure_section_network

function get_configure_filename()
{
    local dest_file=$1
    local default_file=$2
    local src_file=$3

    if [[ ! -f ${dest_file} ]] ; then
        _filename=${src_file}
        [[ -z "${_filename}" ]] &&
        read -p "Where is computer certificate file $(cygpath -w ${default_file}): " _filename
        [[ -z "${_filename}" ]] && _filename="${default_file}"
        [[ ! -r "${_filename}" ]] && \
            csih_error "File ${_filename} doesn't exists."
        csih_inform "copy file from ${_filename} to ${dest_file}"
        _filename=$(cygpath -u ${_filename})
        cp ${_filename} ${dest_file}
    else
        csih_inform "found file: ${dest_file}"
    fi
}
readonly -f get_configure_filename

function configure_section_node()
{
    [[ -r ${node_template_file} ]] ||
    slapos_wget_file ${node_template_file_url} ${node_template_file} ||
    csih_error "Failed to download node configure file."

    get_configure_filename ${node_certificate_file} "/computer.crt" ${_computer_certificate}
    openssl x509 -noout -in ${node_certificate_file} || \
        csih_error "Invalid computer certificate: ${node_certificate_file}."

    get_configure_filename ${node_key_file} "/computer.key" ${_computer_key}
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

    _computer_guid=$(grep "CN=COMP" ${node_certificate_file} | \
        sed -e "s/^.*, CN=//g" | sed -e "s%/emailAddress.*\$%%g")
    [[ "${_computer_guid}" == COMP-+([0-9]) ]] ||
    csih_error "Invalid computer id '$_computer_guid' specified."

    csih_inform "Computer configuration information:"
    csih_inform "  interface name:     ${slapos_ifname}"
    csih_inform "  GUID:               ${interface_guid}"
    csih_inform "  ipv4_local_network: ${_ipv4_local_network}"
    csih_inform "  computer_id:        ${_computer_guid}"
    csih_inform "  user_base_name:     ${slapos_user_basename}"
    csih_inform
    csih_inform "  If ipv4_local_network conflicts with your local network, change it"
    csih_inform "  in the file: ${node_configure_file} "
    csih_inform "  Or change it in $(dirname $0)/slapos-include.sh"
    csih_inform "  and run Configure SlapOS again."

    sed -i  -e "s%^\\s*interface_name.*$%interface_name = ${interface_guid}%" \
        -e "s%^#\?\\s*ipv6_interface.*$%# ipv6_interface =%g" \
        -e "s%^ipv4_local_network.*$%ipv4_local_network = ${_ipv4_local_network}%" \
        -e "s%^computer_id.*$%computer_id = ${_computer_guid}%" \
        -e "s%^user_base_name =.*$%user_base_name = ${slapos_user_basename}%" \
        ${node_configure_file}
}
readonly -f configure_section_node

function configure_section_client()
{
    [[ -r ${client_template_file} ]] ||
    slapos_wget_file ${client_template_file_url} ${client_template_file} ||
    csih_error "Failed to download client configure file."

    sed -i -e "/^alias/,\$d" ${client_template_file}
    echo "alias =
  apache_frontend http://git.erp5.org/gitweb/slapos.git/blob_plain/refs/heads/cygwin-share:/software/apache-frontend/software.cfg
  erp5 http://git.erp5.org/gitweb/slapos.git/blob_plain/refs/tags/slapos-0.143:/software/erp5/software.cfg
  mariadb http://git.erp5.org/gitweb/slapos.git/blob_plain/refs/heads/cygwin-share:/software/mariadb/software.cfg
  mysql http://git.erp5.org/gitweb/slapos.git/blob_plain/refs/heads/cygwin-share:/software/mysql-5.1/software.cfg
  slaposwebrunner http://git.erp5.org/gitweb/slapos.git/blob_plain/refs/heads/cygwin-share:/software/slaprunner-lite/software.cfg
  wordpress http://git.erp5.org/gitweb/slapos.git/blob_plain/refs/heads/cygwin-share:/software/wordpress/software.cfg
  netdrive_reporter http://git.erp5.org/gitweb/slapos.git/blob_plain/refs/heads/cygwin-share:/software/netdrive-reporter/software.cfg
  " >> ${client_template_file}

    get_configure_filename ${client_certificate_file} "/client.crt" ${_client_certificate}
    openssl x509 -noout -in ${client_certificate_file} || \
        csih_error "Invalid client certificate: ${client_certificate_file}."

    get_configure_filename ${client_key_file} "/client.key" ${_client_key}
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
}
readonly -f configure_section_client

function configure_section_openvpn()
{
    local _arch

    if check_openvpn_needed ; then
        csih_inform "Disable IPv6 6to4 interface ... "
        netsh interface ipv6 6to4 set state disable && csih_inform "OK."
        csih_inform "Disable IPv6 isatap interface ... "
        netsh interface ipv6 isatap set state disable && csih_inform "OK."
        csih_inform "Disable IPv6 teredo interface ... "
        netsh interface teredo set state disable && csih_inform "OK."

        check_re6stnet_configure ||
        csih_error "re6stnet hasn't been configured."

        # Check openvpn
        _arch=x86
        check_os_is_wow64 && _arch=x64
        if [[ ! -x /usr/bin/openvpn.exe ]] ; then
            [[ ! -x /opt/openvpn/bin/openvpn.exe ]] &&
            slapos_wget_file http://dashingsoft.com/products/openvpn-${_arch}.tar.gz ~/openvpn.tar.gz &&
            (cd /opt ; tar --no-same-owner xzf ~/openvpn.tar.gz)

            for name in openvpn.exe devcon.exe \
                libeay32.dll  liblzo2-2.dll  libpkcs11-helper-1.dll  ssleay32.dll ; do
                csih_inform "copy /opt/openvpn/bin/${name} to /usr/bin"
                cp /opt/openvpn/bin/${name} /usr/bin ||csih_error "No available openvpn: ${name}"
            done
        fi

        # Check driver
        _path=/etc/slapos/driver
        if [[ ! -f ${_path}/OemWin2k.inf ]] ; then
            mkdir -p ${_path}
            [[ ! -f /opt/openvpn/driver/OemWin2k.inf ]] &&
            slapos_wget_file http://dashingsoft.com/products/openvpn-${_arch}.tar.gz ~/openvpn.tar.gz &&
            (cd /opt ; tar --no-same-owner xzf ~/openvpn.tar.gz)

            for name in OemWin2k.inf tap0901.cat tap0901.sys ; do
                csih_inform "copy /opt/openvpn/driver/${name} to ${_path}"
                cp /opt/openvpn/driver/${name} ${_path} ||csih_error "No available openvpn tap-driver: ${name}"
            done
        fi

        # Check ovpn scripts
        _path=/usr/lib/python2.7/site-packages/re6stnet/re6st
        for name in ovpn-client ovpn-server ; do
            [[ -x ${_path}/${name}.exe ]] && continue
            [[ ! -f /opt/openvpn/re6st/${name}.exe ]] &&
            slapos_wget_file http://dashingsoft.com/products/openvpn-${_arch}.tar.gz ~/openvpn.tar.gz &&
            (cd /opt ; tar --no-same-owner xzf ~/openvpn.tar.gz)

            csih_inform "copy /opt/openvpn/re6st/${name}.exe to ${_path}"
            cp /opt/openvpn/re6st/${name}.exe ${_path} ||csih_error "No available ovpn scripts: ${name}"
        done

        # Install re6stnet service if no native ipv6
        if ! cygrunsrv --query ${re6stnet_service_name} >/dev/null 2>&1 ; then
            if [[ -z "${csih_PRIVILEGED_PASSWORD}" ]] ; then
                slapos_request_password ${_administrator} "Install re6stnet service need the password of ${_administrator}."
            fi
            cygrunsrv -I ${re6stnet_service_name} -c $(dirname ${re6stnet_configure_file}) \
                -p $(which re6stnet) -a "@re6stnet.conf" -d "CYGWIN ${re6stnet_service_name}" \
                -u ${_administrator} -w ${csih_PRIVILEGED_PASSWORD} ||
            csih_error "Failed to install ${re6stnet_service_name} service."
        fi
        csih_inform "you can check log files in /var/log/re6stnet/*.log"
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
        csih_inform "native IPv6 found, no openvpn required."
    fi
}
readonly -f configure_section_openvpn

function configure_section_cron()
{
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
}
readonly -f configure_section_cron

function configure_section_slap_runner()
{
    local _title="SlapOS-WebRunner-In-${_computer_guid}"
    local _patch_file="/etc/slapos/patches/slapos-cookbook-inotifyx.patch"

    csih_check_program_or_error /opt/slapos/bin/slapos slapos

    [[ -z "${_computer_guid}" ]] &&
    csih_error "computer_guid is not set"

    csih_inform "Supply slaposwebrunner in the computer ${_computer_guid}"
    /opt/slapos/bin/slapos supply slaposwebrunner ${_computer_guid}

    csih_inform "Request slaposwebrunner instance as ${_title}"
    /opt/slapos/bin/slapos request ${client_configure_file} \
        ${_title} slaposwebrunner --node computer_guid=${_computer_guid}

    # Apply patch
    [[ -r ${_patch_file} ]] ||
    slapos_wget_file \
        http://git.erp5.org/gitweb/slapos.package.git/blob_plain/heads/cygwin:/windows/patches/$(basename ${_patch_file}) \
        ${_patch_file} ||
    csih_warning "download $(basename ${_patch_file}) failed "

    if [[ -r ${_patch_file} ]] ; then
        for _x in $(find /opt/slapgrid/ -name slapos.cookbook-*.egg) ; do
            patch -d ${_x} -f --dry-run -p1 < ${_patch_file} > /dev/null &&
            csih_inform "Apply patch ${_patch_file} on ${_x}" &&
            patch -d ${_x} -p1 < ${_patch_file}
        done
    fi

    get_slapos_webrunner_instance ${_computer_guid} ${_title}
}
readonly -f configure_section_slap_runner

function configure_section_test_agent()
{
    create_test_agent_instance
}
readonly -f configure_section_test_agent

function remove_configure_items()
{
    if [[ "${_configure_sections}" == *_client_* ]] ; then
        csih_inform "Removing section client ..."

        csih_inform "Remove ${client_configure_file}"
        rm -rf ${client_configure_file} && echo "OK"
        csih_inform "Remove ${client_template_file}"
        rm -rf ${client_template_file} && echo "OK"
        csih_inform "Remove ${client_certificate_file}"
        rm -rf ${client_certificate_file} && echo "OK"
        csih_inform "Remove ${client_key_file}"
        rm -rf ${client_key_file} && echo "OK"

        csih_inform "Remove section client OK"
    fi

    if [[ "${_configure_sections}" == *_cron_* ]] ; then
        csih_inform "Removing section cron ..."

        csih_inform "Remove service ${cron_service_name}"
        cygrunsrv --remove ${cron_service_name} && echo "OK"

        _crontab_file="/var/cron/tabs/${_administrator}"
        csih_inform "Remove ${_crontab_file}"
        rm -rf ${_crontab_file} && echo "OK"

        csih_inform "Remove section cron OK"
    fi

    if [[ "${_configure_sections}" == *_network_* ]] ; then
        csih_inform "Removing network ${slapos_ifname} ..."
        ipwin remove *msloop ${slapos_ifname} && echo "OK"
    fi

    if [[ "${_configure_sections}" == *_node_* ]] ; then
        csih_inform "Removing section node ..."

        csih_inform "Remove ${node_configure_file}"
        rm -rf ${node_configure_file} && echo "OK"
        csih_inform "Remove ${node_template_file}"
        rm -rf ${node_template_file} && echo "OK"
        csih_inform "Remove ${node_certificate_file}"
        rm -rf ${node_certificate_file} && echo "OK"
        csih_inform "Remove ${node_key_file}"
        rm -rf ${node_key_file} && echo "OK"

        csih_inform "Remove section node OK"
    fi

    if [[ "${_configure_sections}" == *_re6stnet_* ]] ; then
        csih_inform "Removing section re6stnet ..."

        csih_inform "Remove /opt/miniupnpc"
        rm -rf /opt/miniupnpc && echo "OK"
        csih_inform "Remove /opt/pyOpenSSL"
        rm -rf /opt/pyOpenSSL && echo "OK"
        csih_inform "Remove /opt/re6stnet"
        rm -rf /opt/re6stnet && echo "OK"
        csih_inform "Remove /etc/re6stnet"
        rm -rf /etc/re6stnet && echo "OK"

        csih_inform "Remove section re6stnet OK"
    fi

    if [[ "${_configure_sections}" == *_openvpn_* ]] ; then
        csih_inform "Removing section openvpn ..."

        csih_inform "Remove service ${re6stnet_service_name}"
        cygrunsrv --remove ${re6stnet_service_name} && echo "OK"

        csih_inform "Remove /etc/slapos/driver"
        rm -rf /etc/slapos/driver && echo "OK"

        csih_inform "Remove /opt/openvpn"
        rm -rf /opt/openvpn && echo "OK"

        csih_inform "Remove section openvpn OK"
    fi

    if [[ "${_configure_sections}" == *_slap-runner_* ]] ; then
        csih_inform "Remove section slap-runner"
    fi

    if [[ "${_configure_sections}" == *_test-agent_* ]] ; then
        csih_inform "Remove section test-agent"
    fi
}
readonly -f remove_configure_items

function get_default_sections()
{
    local sections="_cron_ _network_ _node_"

    [[ -n "${_client_key}" || -n "${_client_certificate}" ]] &&
    sections="$sections _client_"

    [[ -z "${_ipv6_local_address}" ]] &&
    sections="$sections _re6stnet_"

    [[ -z "${_ipv6_local_address}" ]] && check_openvpn_needed &&
    sections="$sections _openvpn_"

    echo $sections
}
readonly -f get_default_sections

# -----------------------------------------------------------
# Local variable
# -----------------------------------------------------------
declare _administrator=${slapos_administrator}
declare _password=
declare _computer_certificate=
declare _computer_key=
declare _client_certificate=
declare _client_key=
declare _ipv4_local_network=
declare _ipv6_local_address=
declare _install_mode=
declare _configure_sections=
declare _computer_guid=

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
    --user)
    _administrator=$optarg
    shift
    ;;
    -U)
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
    --ipv4-local-network=*)
    [[ x$optarg == x*.*.*.*/* ]] ||
    csih_error "invalid --ipv4-local-network=$optarg, no match x.x.x.x/x"
    _ipv4_local_network=$optarg
    ;;
    --ipv6-local-address=*)
    echo $optarg | grep -q "^[:a-fA-F0-9]\+:[a-fA-F0-9]\+$" ||
    csih_error "invalid ipv6-local-address: $optarg"
    _ipv6_local_address=$optarg
    ;;
    -f | --force)
    _install_mode=force
    ;;
    -r | --remove)
    _install_mode=remove
    ;;
    auto | client | cron | openvpn | network | node | re6stnet | \
        slap-runner | test-agent)
    _configure_sections="${_configure_sections} _$1_"
    ;;
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

if [[ -z "${_ipv4_local_network}" ]] ; then
    _ipv4_local_network=$(get_free_local_ipv4_network) ||
    csih_error "no ipv4_local_network specified"
fi

# Get default sections
[[ -z "${_configure_sections}" ]] && _configure_sections=$(get_default_sections)

# -----------------------------------------------------------
# Start script
# -----------------------------------------------------------
csih_inform "Start slapos node configure ..."
csih_inform "Configure section: ${_configure_sections//_/}"
echo ""

# Remove configuration if install mode is 'force' or 'remove'
if [[ -n "${_install_mode}" ]] ; then
    csih_inform "Install mode: ${_install_mode}"
    remove_configure_items
    retcode=$?

    [[ "${_install_mode}" == "remove" ]] && exit $?
fi

# -----------------------------------------------------------
# Check and configure cygwin environments
# -----------------------------------------------------------
configure_sanity_check

if [[ ! ":$PATH" == :/opt/slapos/bin: ]] ; then
    for profile in ~/.bash_profile ~/.profile ; do
        ! grep -q "export PATH=/opt/slapos/bin:" $profile &&
        csih_inform "add /opt/slapos/bin to PATH" &&
        echo "export PATH=/opt/slapos/bin:\${PATH}" >> $profile
    done
fi

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
# Create a super user as slapos administrator
# -----------------------------------------------------------
# echo Checking slapos account ${_administrator} ...
slapos_check_and_create_privileged_user ${_administrator} ${_password} ||
csih_error "failed to create account ${_administrator}."

# Start seclogon service in Windows XP
if csih_is_xp ; then
    csih_inform "Set start property of seclogon to auto"
    sc config seclogon start= auto ||
    csih_warning "failed to set seclogon to auto start."
# In the later, it's RunAs service, and will start by default
fi

# -----------------------------------------------------------
# Configure cygwin services: cygserver syslog-ng
# -----------------------------------------------------------
csih_inform "Starting configure cygwin services ..."
configure_create_cygwin_service
csih_inform "Configure cygwin services OK"
echo ""

# -----------------------------------------------------------
# re6stnet: Install required packages and register to nexedi
# -----------------------------------------------------------
if [[ "${_configure_sections}" == *_re6stnet_* ]] ; then
    csih_inform "Starting configure section re6stnet ..."
    configure_section_re6stnet
    csih_inform "Configure section re6stnet OK"
    echo ""
fi

# -----------------------------------------------------------
# network: Install network connection used by slapos node
# -----------------------------------------------------------
if [[ "${_configure_sections}" == *_network_* ]] ; then
    csih_inform "Starting configure slapos network ..."
    configure_section_network
    csih_inform "Configure section network OK"
    echo ""
fi

# -----------------------------------------------------------
# node: Generate slapos node configure file
# -----------------------------------------------------------
if [[ "${_configure_sections}" == *_node_* ]] ; then
    csih_inform "Starting configure slapos node ..."
    configure_section_node
    csih_inform "Configure section node OK"
    echo ""
fi

# -----------------------------------------------------------
# client: Generate client configure file
# -----------------------------------------------------------
if [[ "${_configure_sections}" == *_client_* ]] ; then
    csih_inform "Starting configure slapos client ..."
    configure_section_client
    csih_inform "Configure slapos client OK"
    echo ""
fi

# -----------------------------------------------------------
# openvpn: Install openvpn and re6stnet service
# -----------------------------------------------------------
if [[ "${_configure_sections}" == *_openvpn_* ]] ; then
    csih_inform "Starting configure section openvpn ..."
    configure_section_openvpn
    csih_inform "Configure section openvpn OK"
    echo ""
fi

# -----------------------------------------------------------
# cron: Install cron service and create crontab
# -----------------------------------------------------------
if [[ "${_configure_sections}" == *_cron_* ]] ; then
    csih_inform "Starting configure section cron ..."
    configure_section_cron
    csih_inform "Configure section cron OK"
    echo ""
fi

# -----------------------------------------------------------
# slap-runner: create instance of slap-runner
# -----------------------------------------------------------
if [[ "${_configure_sections}" == *_slap-runner_* ]] ; then
    csih_inform "Starting configure section slap-runner ..."
    configure_section_slap_runner &&
    csih_inform "Configure section slap-runner OK"
    echo ""
fi

# -----------------------------------------------------------
# test-agent: create instance of test-agent
# -----------------------------------------------------------
if [[ "${_configure_sections}" == *_test-agent_* ]] ; then
    csih_inform "Starting configure section test-agent ..."
    configure_section_test_agent ${_computer_guid} &&
    csih_inform "Configure section test-agent OK"
    echo ""
fi

# -----------------------------------------------------------
# End script
# -----------------------------------------------------------
echo ""
csih_inform "SlapOS has been successfully configured"
echo ""

read -n 1 -t 60 -p "Press any key to exit..."
exit 0
