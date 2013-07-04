#! /bin/bash

# ======================================================================
# Constants
# ======================================================================
slapos_client_home=~/.slapos
client_configure_file=$slapos_client_home/slapos.cfg
client_certificate_file=$slapos_client_home/certificate
client_key_file=$slapos_client_home/key
client_template_file=/etc/slapos/slapos-client.cfg.example

node_certificate_file=/etc/opt/slapos/ssl/computer.crt
node_key_file=/etc/opt/slapos/ssl/computer.key
node_configure_file=/etc/opt/slapos/slapos.cfg
node_template_file=/etc/slapos/slapos.cfg.example

slapos_ifname=re6stnet-lo
# Change it if it confilcts with your local network
ipv4_local_network=10.201.67.0/24

re6stnet_configure_file=/etc/re6stnet/re6stnet.conf
re6stnet_cygwin_script=/etc/re6stnet/ovpn-cygwin.bat
re6stnet_service_name=slapos-re6stnet

slaprunner_startup_file=/etc/slapos/scripts/slap-runner.html

slapos_run_key='\HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'
slapos_run_entry=slapos-configure

# ======================================================================
# Routine: get_system_and_admins_gids
# Get the ADMINs ids from /etc/group and /etc/passwd
# ======================================================================
function get_system_and_admins_ids() {
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

# ======================================================================
# Routine: check_administrator_right
# Check script run as Administrator or not
# ======================================================================
function check_administrator_right()
{
    get_system_and_admins_ids || exit 1
    groups=" $(id -G) "
    if [[ ! $groups == *\ $ADMINSGID\ * ]] ; then
        echo
        echo "You haven't right to run this script $0. "
        echo "Please login as Administrator to run it, or right-click this script and"
        echo "then click Run as administrator."
        echo
        return 1
    fi
}  # === check_administrator_right() === #

# ======================================================================
# Routine: check_administrator_right
# Check cygwin service is install or not, running state, and run by
#   which account
# ======================================================================
function check_cygwin_service()
{
    ret=0
    name=$1

    echo Checking cygwin service $name ...

    if [[ ! -e /usr/bin/cygrunsrv.exe ]] ; then
        echo "Error: Download the cygrunsrv package to start the $name daemon as a service."
        exit 1
    fi
    if ! cygrunsrv --query $name > /dev/null 2>&1 ; then
        echo "Error: No cygwin service $name installed, please run Configure SlapOS to install it."
        return 1
    fi

    account=$(cygrunsrv -VQ $name | sed -n -e 's/^Account[ :]*//p')
    state=$(cygrunsrv --query $name | sed -n -e 's/^Current State[ :]*//p')
    [[ "$state" == "Running" ]] || cygrunsrv --start $name
    state=$(cygrunsrv --query $name | sed -n -e 's/^Current State[ :]*//p')
    cygrunsrv --query $name --verbose
    echo Check cygwin service $name OVER.
    [[ "$state" == "Running" ]] || ret=1
    return "${ret}"
}  # === check_cygwin_service() === #

# ======================================================================
# Routine: check_network_configure
# Check slapos network configure
# ======================================================================
function check_network_configure()
{
    echo Checking slapos network ...
    original_connections=$(echo $(get_all_connections))
    if [[ ! " $original_connections " == *[\ ]$slapos_ifname[\ ]* ]] ; then
        echo "Error: No connection name $slapos_ifname found, please "
        echo "run Configure SlapOS to install it."
        return 1
    fi
    echo Check slapos network Over.
}  # === check_network_configure() === #

# ======================================================================
# Routine: check_node_configure
# Check slapos node configure
# ======================================================================
function check_node_configure()
{
    echo Checking slapos node configure ...
    [[ ! -r $node_certificate_file ]] && \
        ( echo "Computer certificate file $node_certificate_file" ;
          echo "doesn't exists, or you haven't right to visit." ) && \
        return 1
    openssl x509 -noout -in $node_certificate_file || return 1
    openssl rsa -noout -in $node_key_file -check || return 1
    computer_guid=$(grep "CN=COMP" $node_certificate_file | \
        sed -e "s/^.*, CN=//g" | sed -e "s%/emailAddress.*\$%%g")
    [[ ! "$computer_guid" == COMP-+([0-9]) ]] && \
        ( echo "Invalid computer id '$computer_guid' specified." ;
          echo "It should look like 'COMP-XXXX'" ) && \
        return 1

    echo Check slapos node configure Over.
}  # === check_node_configure() === #

# ======================================================================
# Routine: check_client_configure
# Check slapos client configure
# ======================================================================
function check_client_configure()
{
    echo Checking slapos client confiure ...
    echo Check slapos client configure Over.
}  # === check_client_configure() === #

# ======================================================================
# Routine: check_cron_configure
# Check slapos cron configure
# ======================================================================
function check_cron_configure()
{
    echo Checking slapos cron confiure ...
    echo Check slapos cron configure Over.
}  # === check_cron_configure() === #

# ======================================================================
# Routine: check_re6stnet_configure
# Check slapos re6stnet configure
# ======================================================================
function check_re6stnet_configure()
{
    echo Checking slapos re6stnet confiure ...
    ! which re6stnet > /dev/null 2>&1 &&
        echo "No re6stnet installed, please run Configure SlapOS first." &&
        return 1

    echo Check slapos re6stnet configure Over.
}  # === check_re6stnet_configure() === #

# ======================================================================
# Routine: check_re6stnet_needed
# Check re6stnet required or not
# ======================================================================
function check_re6stnet_needed()
{
    # This doesn't work in the cygwin now, need hack ip script
    # re6st-conf --registry http://re6stnet.nexedi.com/ --is-needed
    if netsh interface ipv6 show route | grep -q " ::/0 " ; then
        return 1
    fi
    # re6stnet is required
    return 0
}  # === check_re6stnet_needed() === #

# ======================================================================
# Routine: get_all_connections
# Return all connection names line by line, and replace space with '%'
# ======================================================================
function get_all_connections()
{
    netsh interface ipv6 show interface | \
        grep "^[ 0-9]\+ " | \
        sed -e "s/^[ 0-9]\+[a-zA-Z]\+//" -e "s/^\s*//" -e "s/ /%/g"
}  # === get_all_connections() === #

# ======================================================================
# Routine: get_new_connection
# Check all the connection names, and compare the original connection
# list, return the new connection name
#
# Note: If nothing found, return empty
#       If more than one, return the first one
# ======================================================================
function get_new_connection()
{
    original_connections=" $* "
    current_connections=$(get_all_connections)

    for name in $current_connections ; do
        [[ ! "$original_connections" == *[\ ]$name[\ ]* ]] && \
        echo ${name//%/ } && return 0
    done
}  # === get_new_connections() === #

# ======================================================================
# Routine: reset_slapos_connection
# Remove all ipv4/ipv6 addresses in the connection re6stnet-lo
# ======================================================================
function reset_slapos_connection()
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
}  # === reset_slapos_connection() === #

# ======================================================================
# Routine: connection2guid
# Transfer connection name to GUID
# ======================================================================
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
}  # === connection2guid() === #

# ======================================================================
# Routine: show_error_exit
# Show error message and wait for user to press any key to exit
# ======================================================================
function show_error_exit()
{
    echo ${1-Error: run Configure Slapos failed.}
    read -n 1 -p "Press any key to exit..."
    exit 1
}  # === show_error_exit() === #

# ======================================================================
# Routine: start_cygwin_service
# Start cygwin service if required
# ======================================================================
function start_cygwin_service()
{
    name=$1
    state=$(cygrunsrv --query $name | sed -n -e 's/^Current State[ :]*//p')
    [[ "$state" == "Running" ]] || net start $name
    state=$(cygrunsrv --query $name | sed -n -e 's/^Current State[ :]*//p')
    [[ "$state" == "Running" ]] || return 1
}  # === start_cygwin_service() === #

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

# ======================================================================
# Routine: create_template_configure_file
# Generate the template file for node and client
# ======================================================================
function create_template_configure_file()
{
    cat <<EOF > $client_template_file
[slapos]
master_url = https://slap.vifib.com/

[slapconsole]
# Put here retrieved certificate from SlapOS Master.
# Beware: put certificate from YOUR account, not the one from your node.
# You (as identified person from SlapOS Master) will request an instance, node your node.
# Conclusion: node certificate != person certificate.
cert_file = certificate file location coming from your slapos master account
key_file = key file location coming from your slapos master account
# Below are softwares maintained by slapos.org and contributors
alias =
  apache_frontend http://git.erp5.org/gitweb/slapos.git/blob_plain/HEAD:/software/apache-frontend/software.cfg
  dokuwiki http://git.erp5.org/gitweb/slapos.git/blob_plain/refs/tags/slapos-0.158:/software/dokuwiki/software.cfg
  drupal http://git.erp5.org/gitweb/slapos.git/blob_plain/refs/tags/slapos-0.151:/software/erp5/software.cfg
  erp5 http://git.erp5.org/gitweb/slapos.git/blob_plain/refs/tags/slapos-0.143:/software/erp5/software.cfg
  erp5_branch http://git.erp5.org/gitweb/slapos.git/blob_plain/refs/heads/erp5:/software/erp5/software.cfg
  fengoffice http://git.erp5.org/gitweb/slapos.git/blob_plain/refs/tags/slapos-0.158:/software/fengoffice/software.cfg
  kumofs http://git.erp5.org/gitweb/slapos.git/blob_plain/refs/tags/slapos-0.141:/software/kumofs/software.cfg
  kvm http://git.erp5.org/gitweb/slapos.git/blob_plain/refs/tags/slapos-0.156:/software/kvm/software.cfg
  maarch http://git.erp5.org/gitweb/slapos.git/blob_plain/refs/tags/slapos-0.159:/software/maarch/software.cfg
  mariadb http://git.erp5.org/gitweb/slapos.git/blob_plain/refs/tags/slapos-0.152:/software/mariadb/software.cfg
  memcached http://git.erp5.org/gitweb/slapos.git/blob_plain/refs/tags/slapos-0.82:/software/memcached/software.cfg
  mysql http://git.erp5.org/gitweb/slapos.git/blob_plain/refs/tags/slapos-0.65:/software/mysql-5.1/software.cfg
  opengoo http://git.erp5.org/gitweb/slapos.git/blob_plain/refs/tags/slapos-0.158:/software/opengoo/software.cfg
  postgresql http://git.erp5.org/gitweb/slapos.git/blob_plain/refs/tags/slapos-0.157:/software/postgres/software.cfg
  slaposwebrunner http://git.erp5.org/gitweb/slapos.git/blob_plain/refs/heads/cygwin-0:/software/slaprunner/software.cfg
  slaposwebrunner_lite http://git.erp5.org/gitweb/slapos.git/blob_plain/refs/heads/cygwin-0:/software/slaprunner-lite/software.cfg
  wordpress http://git.erp5.org/gitweb/slapos.git/blob_plain/refs/heads/cygwin:/software/wordpress/software.cfg
  xwiki http://git.erp5.org/gitweb/slapos.git/blob_plain/refs/tags/slapos-0.46:/software/xwiki/software.cfg
  zabbixagent http://git.erp5.org/gitweb/slapos.git/blob_plain/refs/tags/slapos-0.162:/software/zabbix-agent/software.cfg
  netdrive_reporter http://git.erp5.org/gitweb/slapos.git/blob_plain/refs/heads/cygwin-0:/software/netdrive-reporter/software.cfg
  demoapp http://git.erp5.org/gitweb/slapos.git/blob_plain/refs/heads/cygwin-0:/software/demoapp/software.cfg
EOF
    echo $client_template_file has been generated.

    cat <<EOF > $node_template_file
[slapos]
# Replace computer_id by the unique identifier of your computer on vifib.net,
# starting by COMP-
computer_id = COMP-12345
master_url = https://slap.vifib.com/
key_file = /etc/opt/slapos/ssl/computer.key
cert_file =  /etc/opt/slapos/ssl/computer.crt
certificate_repository_path = /etc/opt/slapos/ssl/partition_pki
software_root = /opt/slapgrid
instance_root = /srv/slapgrid

[slapformat]
# Replace by your network interface like eth0, eth1, slapbr0...
interface_name = interfacename
# Change "create_tap" into "true" if you need to host KVM services
create_tap = false
partition_amount = 10
computer_xml = /opt/slapos/slapos.xml
log_file = /opt/slapos/log/slapos-node-format.log
partition_base_name = slappart
user_base_name = slapuser
tap_base_name = slaptap
# You can choose any other local network which does not conflict with your
# current machine configuration
ipv4_local_network = 10.0.0.0/16
# Comment this if you are using native IPv6 and don't want to use SlapOS tunnel
ipv6_interface = tapVPN

[networkcache]
# Define options for binary cache, used to download already compiled software.
download-binary-cache-url = http://www.shacache.org/shacache
download-cache-url = https://www.shacache.org/shacache
download-binary-dir-url = http://www.shacache.org/shadir

# Configuration to Upload Configuration for Binary cache
#upload-binary-dir-url = https://www.shacache.org/shadir
#upload-binary-cache-url = https://www.shacache.org/shacache
#signature_private_key_file = /etc/opt/slapos/shacache/signature.key
#signature_certificate_file = /etc/opt/slapos/shacache/signature.cert
#upload-cache-url = https://www.shacache.org/shacache
#shacache-cert-file = /etc/opt/slapos/shacache/shacache.cert
#shacache-key-file = /etc/opt/slapos/shacache/shacache.key
#upload-binary-dir-url = https://www.shacache.org/shadir
#upload-binary-cache-url = https://www.shacache.org/shacache
#upload-dir-url = https://www.shacache.org/shadir
#shadir-cert-file = /etc/opt/slapos/shacache/shacache.cert
#shadir-key-file = /etc/opt/slapos/shacache/shacache.key

# List of signatures of uploaders we trust:
#   Romain Courteaud
#   Sebastien Robin
#   Kazuhiko Shiozaki
#   Cedric de Saint Martin
#   Yingjie Xu
#   Gabriel Monnerat
#   Łukasz Nowak
#   Test Agent Signature
signature-certificate-list =
  -----BEGIN CERTIFICATE-----
  MIIB4DCCAUkCADANBgkqhkiG9w0BAQsFADA5MQswCQYDVQQGEwJGUjEZMBcGA1UE
  CBMQRGVmYXVsdCBQcm92aW5jZTEPMA0GA1UEChMGTmV4ZWRpMB4XDTExMDkxNTA5
  MDAwMloXDTEyMDkxNTA5MDAwMlowOTELMAkGA1UEBhMCRlIxGTAXBgNVBAgTEERl
  ZmF1bHQgUHJvdmluY2UxDzANBgNVBAoTBk5leGVkaTCBnzANBgkqhkiG9w0BAQEF
  AAOBjQAwgYkCgYEApYZv6OstoqNzxG1KI6iE5U4Ts2Xx9lgLeUGAMyfJLyMmRLhw
  boKOyJ9Xke4dncoBAyNPokUR6iWOcnPHtMvNOsBFZ2f7VA28em3+E1JRYdeNUEtX
  Z0s3HjcouaNAnPfjFTXHYj4um1wOw2cURSPuU5dpzKBbV+/QCb5DLheynisCAwEA
  ATANBgkqhkiG9w0BAQsFAAOBgQBCZLbTVdrw3RZlVVMFezSHrhBYKAukTwZrNmJX
  mHqi2tN8tNo6FX+wmxUUAf3e8R2Ymbdbn2bfbPpcKQ2fG7PuKGvhwMG3BlF9paEC
  q7jdfWO18Zp/BG7tagz0jmmC4y/8akzHsVlruo2+2du2freE8dK746uoMlXlP93g
  QUUGLQ==
  -----END CERTIFICATE-----
  -----BEGIN CERTIFICATE-----
  MIIB8jCCAVugAwIBAgIJAPu2zchZ2BxoMA0GCSqGSIb3DQEBBQUAMBIxEDAOBgNV
  BAMMB3RzeGRldjMwHhcNMTExMDE0MTIxNjIzWhcNMTIxMDEzMTIxNjIzWjASMRAw
  DgYDVQQDDAd0c3hkZXYzMIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCrPbh+
  YGmo6mWmhVb1vTqX0BbeU0jCTB8TK3i6ep3tzSw2rkUGSx3niXn9LNTFNcIn3MZN
  XHqbb4AS2Zxyk/2tr3939qqOrS4YRCtXBwTCuFY6r+a7pZsjiTNddPsEhuj4lEnR
  L8Ax5mmzoi9nE+hiPSwqjRwWRU1+182rzXmN4QIDAQABo1AwTjAdBgNVHQ4EFgQU
  /4XXREzqBbBNJvX5gU8tLWxZaeQwHwYDVR0jBBgwFoAU/4XXREzqBbBNJvX5gU8t
  LWxZaeQwDAYDVR0TBAUwAwEB/zANBgkqhkiG9w0BAQUFAAOBgQA07q/rKoE7fAda
  FED57/SR00OvY9wLlFEF2QJ5OLu+O33YUXDDbGpfUSF9R8l0g9dix1JbWK9nQ6Yd
  R/KCo6D0sw0ZgeQv1aUXbl/xJ9k4jlTxmWbPeiiPZEqU1W9wN5lkGuLxV4CEGTKU
  hJA/yXa1wbwIPGvX3tVKdOEWPRXZLg==
  -----END CERTIFICATE-----
  -----BEGIN CERTIFICATE-----
  MIIB7jCCAVegAwIBAgIJAJWA0jQ4o9DGMA0GCSqGSIb3DQEBBQUAMA8xDTALBgNV
  BAMMBHg2MXMwIBcNMTExMTI0MTAyNDQzWhgPMjExMTEwMzExMDI0NDNaMA8xDTAL
  BgNVBAMMBHg2MXMwgZ8wDQYJKoZIhvcNAQEBBQADgY0AMIGJAoGBANdJNiFsRlkH
  vq2kHP2zdxEyzPAWZH3CQ3Myb3F8hERXTIFSUqntPXDKXDb7Y/laqjMXdj+vptKk
  3Q36J+8VnJbSwjGwmEG6tym9qMSGIPPNw1JXY1R29eF3o4aj21o7DHAkhuNc5Tso
  67fUSKgvyVnyH4G6ShQUAtghPaAwS0KvAgMBAAGjUDBOMB0GA1UdDgQWBBSjxFUE
  RfnTvABRLAa34Ytkhz5vPzAfBgNVHSMEGDAWgBSjxFUERfnTvABRLAa34Ytkhz5v
  PzAMBgNVHRMEBTADAQH/MA0GCSqGSIb3DQEBBQUAA4GBAFLDS7zNhlrQYSQO5KIj
  z2RJe3fj4rLPklo3TmP5KLvendG+LErE2cbKPqnhQ2oVoj6u9tWVwo/g03PMrrnL
  KrDm39slYD/1KoE5kB4l/p6KVOdeJ4I6xcgu9rnkqqHzDwI4v7e8/D3WZbpiFUsY
  vaZhjNYKWQf79l6zXfOvphzJ
  -----END CERTIFICATE-----
  -----BEGIN CERTIFICATE-----
  MIIB9jCCAV+gAwIBAgIJAO4V/jiMoICoMA0GCSqGSIb3DQEBBQUAMBMxETAPBgNV
  BAMMCENPTVAtMjMyMCAXDTEyMDIxNjExMTAyM1oYDzIxMTIwMTIzMTExMDIzWjAT
  MREwDwYDVQQDDAhDT01QLTIzMjCBnzANBgkqhkiG9w0BAQEFAAOBjQAwgYkCgYEA
  wi/3Z8W9pUiegUXIk/AiFDQ0UJ4JFAwjqr+HSRUirlUsHHT+8DzH/hfcTDX1I5BB
  D1ADk+ydXjMm3OZrQcXjn29OUfM5C+g+oqeMnYQImN0DDQIOcUyr7AJc4xhvuXQ1
  P2pJ5NOd3tbd0kexETa1LVhR6EgBC25LyRBRae76qosCAwEAAaNQME4wHQYDVR0O
  BBYEFMDmW9aFy1sKTfCpcRkYnP6zUd1cMB8GA1UdIwQYMBaAFMDmW9aFy1sKTfCp
  cRkYnP6zUd1cMAwGA1UdEwQFMAMBAf8wDQYJKoZIhvcNAQEFBQADgYEAskbFizHr
  b6d3iIyN+wffxz/V9epbKIZVEGJd/6LrTdLiUfJPec7FaxVCWNyKBlCpINBM7cEV
  Gn9t8mdVQflNqOlAMkOlUv1ZugCt9rXYQOV7rrEYJBWirn43BOMn9Flp2nibblby
  If1a2ZoqHRxoNo2yTmm7TSYRORWVS+vvfjY=
  -----END CERTIFICATE-----
  -----BEGIN CERTIFICATE-----
  MIIB9jCCAV+gAwIBAgIJAIlBksrZVkK8MA0GCSqGSIb3DQEBBQUAMBMxETAPBgNV
  BAMMCENPTVAtMzU3MCAXDTEyMDEyNjEwNTUyOFoYDzIxMTIwMTAyMTA1NTI4WjAT
  MREwDwYDVQQDDAhDT01QLTM1NzCBnzANBgkqhkiG9w0BAQEFAAOBjQAwgYkCgYEA
  ts+iGUwi44vtIfwXR8DCnLtHV4ydl0YTK2joJflj0/Ws7mz5BYkxIU4fea/6+VF3
  i11nwBgYgxQyjNztgc9u9O71k1W5tU95yO7U7bFdYd5uxYA9/22fjObaTQoC4Nc9
  mTu6r/VHyJ1yRsunBZXvnk/XaKp7gGE9vNEyJvPn2bkCAwEAAaNQME4wHQYDVR0O
  BBYEFKuGIYu8+6aEkTVg62BRYaD11PILMB8GA1UdIwQYMBaAFKuGIYu8+6aEkTVg
  62BRYaD11PILMAwGA1UdEwQFMAMBAf8wDQYJKoZIhvcNAQEFBQADgYEAMoTRpBxK
  YLEZJbofF7gSrRIcrlUJYXfTfw1QUBOKkGFFDsiJpEg4y5pUk1s5Jq9K3SDzNq/W
  it1oYjOhuGg3al8OOeKFrU6nvNTF1BAvJCl0tr3POai5yXyN5jlK/zPfypmQYxE+
  TaqQSGBJPVXYt6lrq/PRD9ciZgKLOwEqK8w=
  -----END CERTIFICATE-----
  -----BEGIN CERTIFICATE-----
  MIIB9jCCAV+gAwIBAgIJAPHoWu90gbsgMA0GCSqGSIb3DQEBBQUAMBQxEjAQBgNV
  BAMMCXZpZmlibm9kZTAeFw0xMjAzMTkyMzIwNTVaFw0xMzAzMTkyMzIwNTVaMBQx
  EjAQBgNVBAMMCXZpZmlibm9kZTCBnzANBgkqhkiG9w0BAQEFAAOBjQAwgYkCgYEA
  ozBijpO8PS5RTeKTzA90vi9ezvv4vVjNaguqT4UwP9+O1+i6yq1Y2W5zZxw/Klbn
  oudyNzie3/wqs9VfPmcyU9ajFzBv/Tobm3obmOqBN0GSYs5fyGw+O9G3//6ZEhf0
  NinwdKmrRX+d0P5bHewadZWIvlmOupcnVJmkks852BECAwEAAaNQME4wHQYDVR0O
  BBYEFF9EtgfZZs8L2ZxBJxSiY6eTsTEwMB8GA1UdIwQYMBaAFF9EtgfZZs8L2ZxB
  JxSiY6eTsTEwMAwGA1UdEwQFMAMBAf8wDQYJKoZIhvcNAQEFBQADgYEAc43YTfc6
  baSemaMAc/jz8LNLhRE5dLfLOcRSoHda8y0lOrfe4lHT6yP5l8uyWAzLW+g6s3DA
  Yme/bhX0g51BmI6gjKJo5DoPtiXk/Y9lxwD3p7PWi+RhN+AZQ5rpo8UfwnnN059n
  yDuimQfvJjBFMVrdn9iP6SfMjxKaGk6gVmI=
  -----END CERTIFICATE-----
  -----BEGIN CERTIFICATE-----
  MIIB9jCCAV+gAwIBAgIJAMNZBmoIOXPBMA0GCSqGSIb3DQEBBQUAMBMxETAPBgNV
  BAMMCENPTVAtMTMyMCAXDTEyMDUwMjEyMDQyNloYDzIxMTIwNDA4MTIwNDI2WjAT
  MREwDwYDVQQDDAhDT01QLTEzMjCBnzANBgkqhkiG9w0BAQEFAAOBjQAwgYkCgYEA
  6peZQt1sAmMAmSG9BVxxcXm8x15kE9iAplmANYNQ7z2YO57c10jDtlYlwVfi/rct
  xNUOKQtc8UQtV/fJWP0QT0GITdRz5X/TkWiojiFgkopza9/b1hXs5rltYByUGLhg
  7JZ9dZGBihzPfn6U8ESAKiJzQP8Hyz/o81FPfuHCftsCAwEAAaNQME4wHQYDVR0O
  BBYEFNuxsc77Z6/JSKPoyloHNm9zF9yqMB8GA1UdIwQYMBaAFNuxsc77Z6/JSKPo
  yloHNm9zF9yqMAwGA1UdEwQFMAMBAf8wDQYJKoZIhvcNAQEFBQADgYEAl4hBaJy1
  cgiNV2+Z5oNTrHgmzWvSY4duECOTBxeuIOnhql3vLlaQmo0p8Z4c13kTZq2s3nhd
  Loe5mIHsjRVKvzB6SvIaFUYq/EzmHnqNdpIGkT/Mj7r/iUs61btTcGUCLsUiUeci
  Vd0Ozh79JSRpkrdI8R/NRQ2XPHAo+29TT70=
  -----END CERTIFICATE-----
  -----BEGIN CERTIFICATE-----
  MIIB9jCCAV+gAwIBAgIJAKRvzcy7OH0UMA0GCSqGSIb3DQEBBQUAMBMxETAPBgNV
  BAMMCENPTVAtNzcyMCAXDTEyMDgxMDE1NDI1MVoYDzIxMTIwNzE3MTU0MjUxWjAT
  MREwDwYDVQQDDAhDT01QLTc3MjCBnzANBgkqhkiG9w0BAQEFAAOBjQAwgYkCgYEA
  o7aipd6MbnuGDeR1UJUjuMLQUariAyQ2l2ZDS6TfOwjHiPw/mhzkielgk73kqN7A
  sUREx41eTcYCXzTq3WP3xCLE4LxLg1eIhd4nwNHj8H18xR9aP0AGjo4UFl5BOMa1
  mwoyBt3VtfGtUmb8whpeJgHhqrPPxLoON+i6fIbXDaUCAwEAAaNQME4wHQYDVR0O
  BBYEFEfjy3OopT2lOksKmKBNHTJE2hFlMB8GA1UdIwQYMBaAFEfjy3OopT2lOksK
  mKBNHTJE2hFlMAwGA1UdEwQFMAMBAf8wDQYJKoZIhvcNAQEFBQADgYEAaNRx6YN2
  M/p3R8/xS6zvH1EqJ3FFD7XeAQ52WuQnKSREzuw0dsw12ClxjcHiQEFioyTiTtjs
  5pW18Ry5Ie7iFK4cQMerZwWPxBodEbAteYlRsI6kePV7Gf735Y1RpuN8qZ2sYL6e
  x2IMeSwJ82BpdEI5niXxB+iT0HxhmR+XaMI=
  -----END CERTIFICATE-----
# List of URL(s) which shouldn't be downloaded from binary cache.
# Any URL beginning by a blacklisted URL will be blacklisted as well.
download-from-binary-cache-url-blacklist =
  http://git.erp5.org/gitweb/slapos.git/blob_plain/HEAD
  http://git.erp5.org/gitweb/slapos.git/blob_plain/refs/heads
  /
# List of URL(s) which shouldn't be uploaded into binary cache.
# Any URL beginning by a blacklisted URL will be blacklisted as well.
upload-to-binary-cache-url-blacklist =
  http://git.erp5.org/gitweb/slapos.git/blob_plain/HEAD
  http://git.erp5.org/gitweb/slapos.git/blob_plain/refs/heads
  /
EOF
    echo $node_template_file has been generated.
}  # === create_template_configure_file() === #
