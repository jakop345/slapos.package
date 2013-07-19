#! /bin/bash
export PATH=/usr/local/bin:/usr/bin:/usr/sbin:/sbin:/bin:$PATH
if ! source /usr/share/csih/cygwin-service-installation-helper.sh ; then
    echo "Error: Download the csih package at first, I need this file:"
    echo "  /usr/share/csih/cygwin-service-installation-helper.sh"
    exit 1
fi

# Check Administrator rights
csih_get_system_and_admins_ids
if [[ ! " $(id -G) " == *\ $csih_ADMINSUID\ * ]] ; then
    echo
    echo "You haven't right to run this script. "
    echo "Please login as Administrator to run it, or right-click this script"
    echo "then click Run as administrator."
    echo
    exit 1
fi

# ======================================================================
# Constants
# ======================================================================
declare -r slapos_client_home=~/.slapos
declare -r client_configure_file=$slapos_client_home/slapos.cfg
declare -r client_certificate_file=$slapos_client_home/certificate
declare -r client_key_file=$slapos_client_home/key
declare -r client_template_file=/etc/slapos/slapos-client.cfg.example

declare -r node_certificate_file=/etc/opt/slapos/ssl/computer.crt
declare -r node_key_file=/etc/opt/slapos/ssl/computer.key
declare -r node_configure_file=/etc/opt/slapos/slapos.cfg
declare -r node_template_file=/etc/slapos/slapos.cfg.example

declare -r slapos_ifname=re6stnet-lo
# Change it if it confilcts with your local network
declare -r ipv4_local_network=10.201.67.0/24

declare -r openvpn_tap_driver_inf=/etc/slapos/driver/OemWin2k.inf
declare -r openvpn_tap_driver_hwid=tap0901

declare -r re6stnet_configure_file=/etc/re6stnet/re6stnet.conf
declare -r re6stnet_service_name=re6stnet

declare -r slapos_cron_config=/usr/bin/slapos-cron-config
declare -r slaprunner_startup_file=/etc/slapos/scripts/slap-runner.html

declare -r slapos_run_key='\HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'
declare -r slapos_run_entry=slapos-configure
declare -r slapos_admin=slaproot

# ======================================================================
# Routine: check_cygwin_service
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
    if ! netsh interface ipv6 show interface | grep -q "\\b$slapos_ifname\\b" ; then
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
# Routine: reset_slapos_connection
# Remove all ipv4/ipv6 addresses in the connection re6stnet-lo
# ======================================================================
function reset_slapos_connection()
{
    ifname=${1-re6stnet-lo}
    netsh interface ip set address $ifname source=dhcp
}  # === reset_slapos_connection() === #

# ======================================================================
# Routine: show_error_exit
# Show error message and wait for user to press any key to exit
# ======================================================================
function show_error_exit()
{
    echo ${1-Error: configure SlapOS failed.}
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
    local username="${1-slaproot}"

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
# Routine: slapos_create_privileged_user
#
# Copied from csih_check_and_create_privileged_user, just create fix account:
#   slaproot
# ======================================================================
slapos_check_and_create_privileged_user()
{
  csih_stacktrace "${@}"
  $_csih_trace
  local username_in_sam
  local username="${1-slaproot}"
  local admingroup
  local dos_var_empty
  local _password
  local password_value="$2"
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
          if [ -z "${password_value}" ]
          then
              _password="${password_value}"
              csih_inform "Please enter a password for new user ${username}.  Please be sure"
              csih_inform "that this password matches the password rules given on your system."
              csih_inform "Entering no password will exit the configuration."
              csih_get_value "Please enter the password:" -s
              _password="${csih_value}"
              if [ -z "${_password}" ]
              then
                  csih_error_multi "Exiting configuration.  No user ${username} has been created," \
                      "and no services have been installed."
              fi
          fi
          tmpfile1=$(csih_mktemp) || csih_error "Could not create temp file"
          csih_call_winsys32 net user "${username}" "${_password}" /add /fullname:"SlapOS Administraoter" \
              "/homedir:${dos_var_empty}" /yes > "${tmpfile1}" 2>&1 && username_in_sam=yes
          if [ "${username_in_sam}" != "yes" ]
          then
              csih_warning "Creating the user '${username}' failed!  Reason:"
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
      csih_PRIVILEGED_PASSWORD="${password_value}"
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
# Routine: create_template_configure_file
# Generate the template file for node and client
# ======================================================================
function create_template_configure_file()
{
    wget http://git.erp5.org/gitweb/slapos.core.git/blob_plain/HEAD:/slapos-client.cfg.example -O $client_template_file || return 1
    echo Got $client_template_file.

    wget http://git.erp5.org/gitweb/slapos.core.git/blob_plain/HEAD:/slapos.cfg.example -O $node_template_file || return 1
    echo Got $node_template_file.
}  # === create_template_configure_file() === #

# ======================================================================
# Routine: create_slapos_webrunner_instance
# Create one instance of slapos webrunner in local computer
# ======================================================================
function create_slapos_webrunner_instance()
{
    local _title
    local _guid
    local _feature_code="#-*- SlapOS Web Runner JavaScript Boot Code -*-#"
    local _re6stnet_ipv6
    local _patch_file=/etc/slapos/patches/slapos-cookbook-inotifyx.patch
    local _url

    echo Checking SlapOS Webruner ...    
    if grep -q -F "${_feature_code}" ${slaprunner_startup_file} ; then

        echo "Find feature code ${_feature_code} in the ${slaprunner_startup_file}"
        echo "Check SlapOS Webrunner OK."

    else

        echo Installing SlapOS Webrunner ...

        _guid=$(grep "CN=COMP" $node_certificate_file | \
            sed -e "s/^.*, CN=//g" | sed -e "s%/emailAddress.*\$%%g")
        [[ "${_guid}" == COMP-+([0-9]) ]] ||
        csih_error "Invalid computer id '${_guid}' specified."
        echo Got computer guid: ${_guid}

        _title="SlapOS-Node-Runner-In-${_guid}"
        if [[ -r $re6stnet_configure_file ]] ; then
            _re6stnet_ipv6=$(grep "Your subnet" $re6stnet_configure_file| \
                sed -e "s/^.*subnet: //g" -e "s/\/80 (CN.*\$/1/g")
            if [[ -n "${_re6stnet_ipv6}" ]] ; then
                echo "Re6stnet address in this computer: ${_re6stnet_ipv6}"
                netsh interface ipv6 show addr $slapos_ifname level=normal | \
                    grep -q "${_re6stnet_ipv6}$$" || \
                    netsh interface ipv6 add addr $slapos_ifname ${_re6stnet_ipv6}
            fi
        fi

        /opt/slapos/bin/slapos node format -cv --now || \
            csih_error "Failed to run slapos format."

        echo "Supply slapwebrunner in the computer ${_guid}"
        /opt/slapos/bin/slapos supply slaposwebrunner ${_guid}

        echo "Request an instance ${_title} ..."
        while true ; do
            /opt/slapos/bin/slapos node software --verbose
            # Apply patches to slapos.cookbook for inotifix
            if [[ -r ${_patch_file} ]] ; then
                for x in $(find /opt/slapgrid/ -name slapos.cookbook-*.egg) ; do
                    echo Apply patch ${_patch_file} at $x
                    cd $x
                    patch -f --dry-run -p1 < ${_patch_file} > /dev/null && \
                        patch -p1 < ${_patch_file}
                done
            fi
            /opt/slapos/bin/slapos node instance --verbose
            /opt/slapos/bin/slapos node report --verbose

            # Connection parameters of instance are:
            #  {'backend_url': 'http://[2001:67c:1254:45::c5d5]:50000',
            #  'cloud9-url': 'http://localhost:9999',
            #  'password_recovery_code': 'e2d01c14',
            #  'ssh_command': 'ssh 2001:67c:1254:45::c5d5 -p 2222',
            #  'url': 'http://softinst39090.host.vifib.net/'}
            _url=$(/opt/slapos/bin/slapos request ${client_configure_file} \
                ${_title} slaposwebrunner --node computer_guid=${_guid} | \
                grep backend_url | sed -e "s/^.*': '//g" -e "s/',.*$//g")            
            [[ -n "${_url}" ]] && echo "SlapOS Web Runner URL: ${_url}" && break
        done

        cat <<EOF > $slaprunner_startup_file
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
        echo SlapOS Webrunner boot file $slaprunner_startup_file generated.
        echo Install Web Runner OK.
        echo
    fi
}  # === create_slapos_webrunner_instance() === #
