#! /bin/bash
export PATH=/usr/local/bin:/usr/bin:/usr/sbin:/sbin:/bin:$PATH
if ! source /usr/share/csih/cygwin-service-installation-helper.sh ; then
    echo "Download the csih package at first, to run this script requires"
    echo "  /usr/share/csih/cygwin-service-installation-helper.sh"
    exit 1
fi

# Check Administrator rights
csih_get_system_and_admins_ids
if [[ ! " $(id -G) " == *\ $csih_ADMINSUID\ * ]] ; then
    echo
    echo "You don't have the rights to run this script. "
    echo "Please login as Administrator to run it, or right-click this script"
    echo "then click Run as administrator."
    echo
    exit 1
fi

# ======================================================================
# Constants
# ======================================================================
declare -r slapos_prefix=

declare -r slapos_client_home=~/.slapos
declare -r client_configure_file=$slapos_client_home/slapos-client.cfg
declare -r client_certificate_file=$slapos_client_home/client.crt
declare -r client_key_file=$slapos_client_home/client.key
declare -r client_template_file=/etc/slapos/slapos-client.cfg.example
declare -r client_template_file_url=http://git.erp5.org/gitweb/slapos.core.git/blob_plain/HEAD:/slapos-client.cfg.example

declare -r node_certificate_file=/etc/opt/slapos/ssl/computer.crt
declare -r node_key_file=/etc/opt/slapos/ssl/computer.key
declare -r node_configure_file=/etc/opt/slapos/slapos.cfg
declare -r node_template_file=/etc/slapos/slapos.cfg.example
declare -r node_template_file_url=http://git.erp5.org/gitweb/slapos.core.git/blob_plain/HEAD:/slapos.cfg.example

declare -r openvpn_tap_driver_inf=/etc/slapos/driver/OemWin2k.inf
declare -r openvpn_tap_driver_hwid=tap0901

declare -r re6stnet_configure_file=/etc/re6stnet/re6stnet.conf
declare -r slapos_cron_config=/usr/bin/slapos-cron-config
declare -r slaprunner_startup_file=/etc/slapos/scripts/slap-runner.html

declare -r slapos_administrator=${slapos_prefix:-slap}root
declare -r slapos_user_basename=${slapos_prefix:-slap}user
declare -r slapos_ifname=${slapos_prefix}re6stnet-lo
declare -r re6stnet_service_name=${slapos_prefix}re6stnet
declare -r cron_service_name=${slapos_prefix}cron
declare -r syslog_service_name=${slapos_prefix}syslog-ng
declare -r cygserver_service_name=${slapos_prefix}cygserver

# ======================================================================
# Routine: check_os_is_wow64
# ======================================================================
function check_os_is_wow64()
{
  [[ $(uname) == CYGWIN_NT-*-WOW64 ]]
}  # === check_os_is_wow64 === #
readonly -f check_os_is_wow64

# ======================================================================
# Routine: check_cygwin_service
# Check cygwin service is install or not, running state, and run by
#   which account
# ======================================================================
function check_cygwin_service()
{
    ret=0
    name=$1

    csih_inform "Checking cygwin service $name ..."

    if [[ ! -e /usr/bin/cygrunsrv.exe ]] ; then
        csih_error "Download cygrunsrv package to start the $name daemon as a service."
    fi
    if ! cygrunsrv --query $name > /dev/null 2>&1 ; then
        csih_error "No cygwin service $name installed, please run Configure SlapOS to install it."
    fi

    account=$(cygrunsrv -VQ $name | sed -n -e 's/^Account[ :]*//p')
    state=$(cygrunsrv --query $name | sed -n -e 's/^Current State[ :]*//p')
    [[ "$state" == "Running" ]] || cygrunsrv --start $name
    state=$(cygrunsrv --query $name | sed -n -e 's/^Current State[ :]*//p')
    cygrunsrv --query $name --verbose
    csih_inform "Check cygwin service $name OVER."
    [[ "$state" == "Running" ]] || ret=1
    return "${ret}"
}  # === check_cygwin_service() === #

# ======================================================================
# Routine: check_network_configure
# Check slapos network configure
# ======================================================================
function check_network_configure()
{
    csih_inform "Checking slapos network ..."
    if ! netsh interface ipv6 show interface | grep -q "\\b$slapos_ifname\\b" ; then
        csih_error_multi "Error: No connection name $slapos_ifname found, please " \
            "run Configure SlapOS to install it."
    fi
    csih_inform "Check slapos network Over."
}  # === check_network_configure() === #

# ======================================================================
# Routine: check_node_configure
# Check slapos node configure
# ======================================================================
function check_node_configure()
{
    csih_inform "Checking slapos node configure ..."
    [[ ! -r $node_certificate_file ]] &&
    csih_error_multi"Computer certificate file $node_certificate_file" \
        "doesn't exists, or you haven't right to visit."
    openssl x509 -noout -in $node_certificate_file || return 1
    openssl rsa -noout -in $node_key_file -check || return 1
    computer_guid=$(grep "CN=COMP" $node_certificate_file | \
        sed -e "s/^.*, CN=//g" | sed -e "s%/emailAddress.*\$%%g")
    [[ ! "$computer_guid" == COMP-+([0-9]) ]] &&
    csih_error_multi "Invalid computer id '$computer_guid' specified." \
        "It should look like 'COMP-XXXX'"
    csih_inform "Check slapos node configure Over."
}  # === check_node_configure() === #

# ======================================================================
# Routine: check_client_configure
# Check slapos client configure
# ======================================================================
function check_client_configure()
{
    csih_inform "Checking slapos client configure ..."
    [[ -f ${client_configure_file} ]] ||
    csih_error "Missing client configure file: ${client_configure_file}"
    csih_inform "Check slapos client configure Over."
}  # === check_client_configure() === #

# ======================================================================
# Routine: check_cron_configure
# Check slapos cron configure
# ======================================================================
function check_cron_configure()
{
    csih_inform "Checking slapos cron configure ..."
    csih_inform "Check slapos cron configure Over."
}  # === check_cron_configure() === #

# ======================================================================
# Routine: check_re6stnet_configure
# Check slapos re6stnet configure
# ======================================================================
function check_re6stnet_configure()
{
    csih_inform "Checking slapos re6stnet configure ..."
    which re6stnet > /dev/null 2>&1 ||
    csih_warning "No re6stnet installed."
    csih_inform "Check slapos re6stnet configure Over."
}  # === check_re6stnet_configure() === #

# ======================================================================
# Routine: check_openvpn_needed
# Check re6stnet required or not
# ======================================================================
function check_openvpn_needed()
{
    # This doesn't work in cygwin now, need hack ip script
    # re6st-conf --registry http://re6stnet.nexedi.com/ --is-needed
    if netsh interface ipv6 show route | grep -q " ::/0 " ; then
        return 1
    fi
    # re6stnet is required
    return 0
}  # === check_openvpn_needed() === #

# ======================================================================
# Routine: reset_slapos_connection
# Remove all ipv4/ipv6 addresses in the connection re6stnet-lo
# ======================================================================
function reset_slapos_connection()
{
    ifname=${1:-re6stnet-lo}
    netsh interface ip set address $ifname source=dhcp
}  # === reset_slapos_connection() === #

# ======================================================================
# Routine: get_free_local_ipv4_network
# Get a free local ipv4 network in 10.x.x.0/24, return 10.x.x.0/24
# ======================================================================
function get_free_local_ipv4_network()
{
    local addr=${1}
    local -i i=10
    local -i seg1=
    local -i seg2=

    [[ -n "${addr}" ]] &&
    [[ ${addr} == 10.*.* ]] &&
    ! IPCONFIG /ALL | grep -q ${addr} &&
    echo ${addr} &&
    return 0
        
    while (( i )) ; do
        let seg1=($RANDOM % 255) 2>&1 > /dev/null
        let seg2=($RANDOM % 255) 2>&1 > /dev/null
        addr=${seg1}.${seg2}
    
        ! IPCONFIG /ALL | grep -q ${addr} &&
        echo "10.${addr}.0/24" &&
        return 0
    
        let i--
    done

    # No found
    return 1
}  # === get_free_local_ipv4_network() === #
readonly -f get_free_local_ipv4_network

# ======================================================================
# Routine: show_error_exit
# Show error message and wait for user to press any key to exit
# ======================================================================
function show_error_exit()
{
    echo ${1:-"Error: configure SlapOS failed."}
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

# ======================================================================
# Routine: slapos_request_password
# Get slaproot password, save it to _password
# ======================================================================
slapos_request_password()
{
    local username="${1:-slaproot}"

    csih_inform "$2"
    csih_get_value "Please enter the password:" -s
    _password="${csih_value}"
    if [ -z "${_password}" ]
    then
        csih_error_multi "Exiting configuration." "I don't know the password of ${username}."
    fi
    csih_PRIVILEGED_PASSWORD="${_password}"
}  # === slapos_request_password() === #

# ======================================================================
# Routine: wget_slapos_file
# Generate the template file for node and client
# ======================================================================
function slapos_wget_file()
{
    wget $1 -O $2 || return 1
    csih_inform "Got $2."
}  # === wget_slapos_file() === #
readonly -f slapos_wget_file

# ======================================================================
# Routine: slapos_create_privileged_user
#
# Copied from csih_check_and_create_privileged_user
# 
# ======================================================================
slapos_check_and_create_privileged_user()
{
  csih_stacktrace "${@}"
  $_csih_trace
  local username_in_sam
  local username="${1:-slaproot}"
  local admingroup
  local dos_var_empty
  local _password="$2"
  local passwd_has_expiry_flags
  local ret=0
  local username_in_admingroup
  local username_got_all_rights
  local pwd_entry
  local username_in_passwd
  local entry_in_passwd
  local tmpfile1
  local tmpfile2

  _csih_setup

  csih_PRIVILEGED_USERNAME="${username}"

  if ! csih_privileged_account_exists "$csih_PRIVILEGED_USERNAME"
  then
      username_in_sam=no
      dos_var_empty=$(/usr/bin/cygpath -w ${LOCALSTATEDIR}/empty)
      while [ "${username_in_sam}" != "yes" ]
      do
          if [ -z "${_password}" ]
          then
              csih_inform "Please enter a password for new user ${username}.  Please be sure"
              csih_inform "that this password matches the password rules given on your system."
              csih_inform "Entering no password will exit the configuration."
              csih_get_value "Please enter the password:" -s
              _password="${csih_value}"
              if [ -z "${_password}" ]
              then
                  csih_error_multi "Exiting configuration.  No user ${username} has been created," \
                      "and no service has been installed."
              fi
          fi
          tmpfile1=$(csih_mktemp) || csih_error "Could not create temp file"
          csih_call_winsys32 net user "${username}" "${_password}" /add /fullname:"SlapOS Administrator" \
              "/homedir:${dos_var_empty}" /yes > "${tmpfile1}" 2>&1 && username_in_sam=yes
          if [ "${username_in_sam}" != "yes" ]
          then
              csih_warning "Creation of user '${username}' failed!  Reason:"
              /usr/bin/cat "${tmpfile1}"
              echo
          fi
          /usr/bin/rm -f "${tmpfile1}"
      done

      csih_PRIVILEGED_PASSWORD="${_password}"
      csih_inform "User '${username}' has been created with password '${_password}'."
      csih_inform "If you change the password, please remember also to change the"
      csih_inform "password for the installed services which use (or will soon use)"
      csih_inform "the '${username}' account."
      echo ""
      csih_inform "Also keep in mind that the user '${username}' needs read permissions"
      csih_inform "on all users' relevant files for the services running as '${username}'."
      csih_inform "In particular, for the sshd server all users' .ssh/authorized_keys"
      csih_inform "files must have appropriate permissions to allow public key"
      csih_inform "authentication. (Re-)running ssh-user-config for each user will set"
      csih_inform "these permissions correctly. [Similar restrictions apply, for"
      csih_inform "instance, for .rhosts files if the rshd server is running, etc]."
      echo ""

      if ! passwd -e "${username}"
      then
          csih_warning "Setting password expiry for user '${username}' failed!"
          csih_warning "Please check that password never expires or set it to your needs."
      fi
  else
      # ${username} already exists. Use it, and make no changes.
      # use passed-in value as first guess
      csih_PRIVILEGED_PASSWORD="${_password}"
  fi

  # username did NOT previously exist, but has been successfully created.
  # set group memberships, privileges, and passwd timeout.
  if [ "$username_in_sam" = "yes" ]
  then
      # always try to set group membership and privileges
      admingroup=$(/usr/bin/mkgroup -l | /usr/bin/awk -F: '{if ( $2 == "S-1-5-32-544" ) print $1;}')
      if [ -z "${admingroup}" ]
      then
        csih_warning "Cannot obtain the Administrators group name from 'mkgroup -l'."
        ret=1
      elif csih_call_winsys32 net localgroup "${admingroup}" | /usr/bin/grep -Eiq "^${username}.?$"
      then
          true
      else
          csih_call_winsys32 net localgroup "${admingroup}" "${username}" /add > /dev/null 2>&1 && username_in_admingroup=yes
          if [ "${username_in_admingroup}" != "yes" ]
          then
              csih_warning "Adding user '${username}' to local group '${admingroup}' failed!"
              csih_warning "Please add '${username}' to local group '${admingroup}' before"
              csih_warning "starting any of the services which depend upon this user!"
              ret=1
          fi
      fi

      if ! csih_check_program_or_warn /usr/bin/editrights editrights
      then
          csih_warning "The 'editrights' program cannot be found or is not executable."
          csih_warning "Unable to ensure that '${username}' has the appropriate privileges."
          ret=1
      else
          /usr/bin/editrights -a SeAssignPrimaryTokenPrivilege -u ${username} &&
          /usr/bin/editrights -a SeCreateTokenPrivilege -u ${username} &&
          /usr/bin/editrights -a SeTcbPrivilege -u ${username} &&
          /usr/bin/editrights -a SeDenyRemoteInteractiveLogonRight -u ${username} &&
          /usr/bin/editrights -a SeServiceLogonRight -u ${username} &&
          username_got_all_rights="yes"
          if [ "${username_got_all_rights}" != "yes" ]
          then
              csih_warning "Assigning the appropriate privileges to user '${username}' failed!"
              ret=1
          fi
      fi
  fi # ! username_in_sam

  # we just created the user, so of course it's in the local SAM,
  # and mkpasswd -l is appropriate
  pwd_entry="$(/usr/bin/mkpasswd -l -u "${username}" | /usr/bin/sed -n -e '/^'${username}'/s?\(^[^:]*:[^:]*:[^:]*:[^:]*:[^:]*:\).*?\1'${LOCALSTATEDIR}'/empty:/bin/false?p')"
  /usr/bin/grep -Eiq "^${username}:" "${SYSCONFDIR}/passwd" && username_in_passwd=yes &&
  /usr/bin/grep -Fiq "${pwd_entry}" "${SYSCONFDIR}/passwd" && entry_in_passwd=yes
  if [ "${entry_in_passwd}" != "yes" ]
  then
      if [ "${username_in_passwd}" = "yes" ]
      then
          tmpfile2=$(csih_mktemp) || csih_error "Could not create temp file"
	  /usr/bin/chmod --reference="${SYSCONFDIR}/passwd" "${tmpfile2}"
	  /usr/bin/chown --reference="${SYSCONFDIR}/passwd" "${tmpfile2}"
          /usr/bin/getfacl "${SYSCONFDIR}/passwd" | /usr/bin/setfacl -f - "${tmpfile2}"
	      # use >> instead of > to preserve permissions and acls
          /usr/bin/grep -Ev "^${username}:" "${SYSCONFDIR}/passwd" >> "${tmpfile2}" &&
          /usr/bin/mv -f "${tmpfile2}" "${SYSCONFDIR}/passwd" || return 1
      fi
      echo "${pwd_entry}" >> "${SYSCONFDIR}/passwd" || ret=1
  fi
  return "${ret}"
} # === End of csih_check_and_create_privileged_user() === #
readonly -f slapos_check_and_create_privileged_user

# ======================================================================
# Routine: get_slapos_webrunner_instance
# Get instance connection information and create slaprunner startup file
# ======================================================================
function get_slapos_webrunner_instance()
{
    local _guid=$1
    local _title=$2
    local _feature_code="#-*- SlapOS Web Runner JavaScript Boot Code -*-#"
    local _url=
    local _ret=0

    csih_inform "Trying to get connection information of SlapOS WebRunner instance ..."
    /opt/slapos/bin/slapos request --cfg ${client_configure_file} \
        ${_title} slaposwebrunner --node computer_guid=${_guid} || return 1

    # Connection parameters of instance are:
    #  {'backend_url': 'http://[2001:67c:1254:45::c5d5]:50000',
    #  'cloud9-url': 'http://localhost:9999',
    #  'password_recovery_code': 'e2d01c14',
    #  'ssh_command': 'ssh 2001:67c:1254:45::c5d5 -p 2222',
    #  'url': 'http://softinst39090.host.vifib.net/'}
    _url=$(/opt/slapos/bin/slapos request --cfg ${client_configure_file} \
        ${_title} slaposwebrunner --node computer_guid=${_guid} | \
        grep backend_url | sed -e "s/^.*': '//g" -e "s/',.*$//g")

    if [[ -n "${_url}" ]] ; then
        csih_inform "SlapOS WebRunner URL: ${_url}"
        csih_inform "Generate SlapOS WebRunner startup file ${slaprunner_startup_file}"
        cat <<EOF > ${slaprunner_startup_file}
<html>
<head><title>SlapOS Web Runner</title>
<script LANGUAGE="JavaScript">
<!--
function openwin() {
  window.location.href = "${_url}"
}
//-->
</script>
</head>
<body onload="openwin()"/>
<!-- $feature_code -->
</html>
EOF
    else
        csih_error_multi "Request returned true, but I can't find connection information," \
            "something is wrong with slapos webrunner software."
    fi
    return ${_ret}
}  # === get_slapos_webrunner_instance() === #
readonly -f get_slapos_webrunner_instance

# ======================================================================
# Routine: create_test_agent_instance
# Create test-agent instance
# ======================================================================
function create_test_agent_instance()
{
    local computer_guid=${1:-COMP-XXXX}

    cat <<EOF > ~/test-agent.template
<?xml version='1.0' encoding='utf-8'?>
<instance>
<parameter id="usercertificate">-----BEGIN CERTIFICATE-----
MIIEBTCCAu2gAwIBAgIDAJNnMA0GCSqGSIb3DQEBBQUAMIGZMQswCQYDVQQGEwJG
UjEbMBkGA1UECAwSTm9yZC1QYXMtZGUtQ2FsYWlzMQ4wDAYDVQQHDAVMaWxsZTET
MBEGA1UECgwKVmlGaUIgU0FSTDEoMCYGA1UEAwwfQXV0b21hdGljIENlcnRpZmlj
YXRlIEF1dGhvcml0eTEeMBwGCSqGSIb3DQEJARYPYWRtaW5AdmlmaWIuY29tMB4X
DTEzMDYyNzEzMzUxNVoXDTIzMDYyNTEzMzUxNVowczELMAkGA1UEBhMCRlIxGzAZ
BgNVBAgMEk5vcmQtUGFzLWRlLUNhbGFpczETMBEGA1UECgwKVmlGaUIgU0FSTDES
MBAGA1UEAwwJQ09NUC0xNjU1MR4wHAYJKoZIhvcNAQkBFg9hZG1pbkB2aWZpYi5v
cmcwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDwFsiIAFuoSeZmp1tP
dtdgvf63fV6BRMqcmoi14lDXE6A6a6GZSUJfcjE/hl1pMTkSb2C6t652z64Xg9oR
GMlBmrHX6WeZkgcw5wxU1aKeS4yZ6kPvdVf+RvnGiez1yHaAfb/A1OjrbhyH5nn+
yXvWMU+5jIKdTvnHtft02tjOS1s80JNFyP6i8WqJ5Ui6DOVj6TmRQitw4hw3h+4b
VBCPBtOX8qN0ASRWi4IdQToBkzkspYPYtuWFhqEG0gxi2M3M7NAnBLs4vfveOo7C
fCsMOrf1XgpkOg9U8pGv93ot+cCEgaLbldcmUvrFGEaPUTiGfrXB3/ViLHg9eCeY
xgmPAgMBAAGjezB5MAkGA1UdEwQCMAAwLAYJYIZIAYb4QgENBB8WHU9wZW5TU0wg
R2VuZXJhdGVkIENlcnRpZmljYXRlMB0GA1UdDgQWBBTyDEjz/fIvjVo2j6Jay7my
Zlu5lTAfBgNVHSMEGDAWgBRjhJik1R6prfda41XfXWOP+F65uzANBgkqhkiG9w0B
AQUFAAOCAQEANaJzQ+0Ifn3AIf1DrJoXO1g6ywfHTSeDFOmnfVCYb1uECnElBccB
gV/MHl9hq6nyGawamPki9kTqZE6RhM72y+btNxqLELEaMZaXXkZn3ROT0oz2PWFT
WOgTyI/QsHKlMhwa0rxX68G8sSoSw448ICPOQWT0eYAWxnniDW4QCxRZscSlVDFU
heRljeJjwHrz1sRJev4CrOrg44tAlLdJpnO1ZHc+wtXRUJK6YQqKj8UQ/KmvuvWX
br3Xyhksoy67Y+TsS7NzUy+3TFXUpe23JTqETHUPvUU0w4VMUBCcAMYIoh46SHvZ
Dc8/wOQ7Z31zs02v/EQL76HQAfq4n+QvOQ==
-----END CERTIFICATE-----
</parameter>
<parameter id="userkey">-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQDwFsiIAFuoSeZm
p1tPdtdgvf63fV6BRMqcmoi14lDXE6A6a6GZSUJfcjE/hl1pMTkSb2C6t652z64X
g9oRGMlBmrHX6WeZkgcw5wxU1aKeS4yZ6kPvdVf+RvnGiez1yHaAfb/A1OjrbhyH
5nn+yXvWMU+5jIKdTvnHtft02tjOS1s80JNFyP6i8WqJ5Ui6DOVj6TmRQitw4hw3
h+4bVBCPBtOX8qN0ASRWi4IdQToBkzkspYPYtuWFhqEG0gxi2M3M7NAnBLs4vfve
Oo7CfCsMOrf1XgpkOg9U8pGv93ot+cCEgaLbldcmUvrFGEaPUTiGfrXB3/ViLHg9
eCeYxgmPAgMBAAECggEARY+UUjMoWz3uD1f10LQx+smRf0BHnVR9D5qGeYw0t9vr
1IFStMLRBC5lrm4TqmKkkn7Km86UMcBCRHXjPIjd5rAXTuNFLO1uP/DxVbMABrUE
66NAQ6TP9dBClg9oJF4MV3YXlJsbUPr6MTXJqtRdmNV4r93SChnTrNVBIb42iq4i
9bpVSnql8Yr+9jZZnpRDz4IbSxlE3KAHXFmbJThtwc1FcvnYargNdjX9TGx25hyx
hCUsyoCuJURmbwOd3DQjzfxKZT7uLt/nduNYbBNjstzc/HJ4qpuV500DT1kTDPf8
LSp1LnjxzRCHdZwV+jtFebBOfa9euKMAVVYn5fBVIQKBgQD8nPDjrQEfj2igei3l
R9E2KCeS0L+3scVPnytUAvgmZdlCyMcmNvnLl5W2Lwt8zgZaYAlcZpUR+m/zz0PX
Ms9Pwr57CXyQo6K49l819myEPgeVXgETFY3F5/6Nmq6ma4w0GGvaSjxetlYb46D9
oB9iBUzQzEEczO+ozbUxVm2QHQKBgQDzTtr0E07LqMvsgW8752Ufn8S90ThM8jmY
7R/wV9bHPSUOFSACtF3mYuk84Pk9dpbaJmtIL1kz1XnbEHvAmJP7O9kerjR5/sde
22pSR4+FEdGiRuigadmGtCdf+RMU7o3/i2+msB06cjirrGf5hRmS6z+ynfYLHTkF
rzPDrDRomwKBgQC2HTKxANVxekLUhqC1zfuuzm4RMvs0JC36Q+bJr0ZU8FIcCoFA
NJwLQaIF8I6YkDMWTmwROEc56dFx9LeU2iWI+/2019b8s2uparyjO59qCwoOjfG6
X2yRA7qJPb2xbpFqMTz351L0eQFFI+q5Tgmx8d46HTbH25rfmEWLZyKfpQKBgCm4
recIoIxfx4gosdBN35NKrEv4YnUfXC0TDFUEWvoTTBVcHf8YurlU4LXlxhd6DGgg
Cml4ZQ10X87mxrHB+C4ulw6hxLHetIVZjqPJTZz97zqqeh13yStGHTJh3ZnLRmI5
oM2uiXSKPZmCmNm6ryX4XRXd7GD/g9Wrs26sSthdAoGACzZqufKsXBhW71qJAPNO
KK90Fb4QQPjaATY0tUe/Y3I18N7vkD7Z5nhj6R+i1UBSzAD0YKrXi6ROpy3mHeRt
Sz8iN27b5Hyh461RFz6FLKiLofxY9gMaFYewayhvjKrOJXZ84xHS6Nfw5S6Ub5sz
Eb4Vzgi4hhbpk2KbAHOy7Xw=
-----END PRIVATE KEY-----</parameter>
<parameter id="master-url">https://slap.vifib.com/</parameter>
<parameter id="default_max_install_duration">36000</parameter>
<parameter id="default_max_uninstall_duration">36000</parameter>
<parameter id="default_max_request_duration">36000</parameter>
<parameter id="default_max_destroy_duration">36000</parameter>
<parameter id="configuration">

[agent]
node_title = VIFIB-TEST-AGENT-ON-${computer_guid}
test_title = VIFIB-TEST-AGENT-FOR-WINDOWS-INSTALLER
project_title = SlapOS For Windows
task_count = 1
report_url = https://webbuildbot:a2fgt5e1@www.tiolive.com/nexedi/

###### windows self installer ############################################
[test-windows-installer-on-windows7-64bits]
computer_list = ["${computer_guid}"]
url = http://git.erp5.org/gitweb/slapos.git/blob_plain/refs/heads/cygwin-share:/software/slapos-windows-installer/software.cfg
request_kw = {"filter_kw": {"computer_guid": "${computer_guid}"},"partition_parameter_kw": {}}
</parameter>
</instance>
EOF
} # === create_test_agent_instance() === #
readonly -f create_test_agent_instance
