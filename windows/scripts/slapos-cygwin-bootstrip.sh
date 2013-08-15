#! /bin/bash
#
function check_os_is_wow64()
{
  [[ $(uname) == CYGWIN_NT-*-WOW64 ]]
}
readonly -f check_os_is_wow64

function show_usage()
{
    echo "This script is used to build a bootstrip slapos in cywin."
    echo ""
    echo "Usage:"
    echo ""
    echo "  ./slapos-cygwin-bootstrip.sh"
    echo ""
    echo "Before run this script, type the following command in the windows"
    echo "command console to install cygwin:"
    echo ""
    echo "  setup_cygwin.bat C:\slapos-bootstrip network"
    echo ""
    echo "Then sign up slapos.org, got the following certificate files:"
    echo ""
    echo "  certificate"
    echo "  key"
    echo "  computer.key"
    echo "  computer.crt"
    echo ""
    echo "save them in your home path."
    echo ""
    echo "Register another computer for test node, save them in the root path"
    echo ""
    echo "  test-computer.key"
    echo "  test-computer.crt"
    echo ""
    echo ""
}
readonly -f show_usage

export PATH=/usr/local/bin:/usr/bin:/usr/sbin:/sbin:/bin:$PATH
if ! source /usr/share/csih/cygwin-service-installation-helper.sh ; then
    echo "Error: Missing csih package."
    exit 1
fi

csih_inform "Starting bootstrip slapos node ..."
echo ""

# ======================================================================
# Constants
# ======================================================================
declare -r slapos_client_home=~/.slapos
declare -r client_configure_file=$slapos_client_home/slapos.cfg
declare -r client_certificate_file=$slapos_client_home/certificate
declare -r client_key_file=$slapos_client_home/key

declare -r node_certificate_file=/etc/opt/slapos/ssl/computer.crt
declare -r node_key_file=/etc/opt/slapos/ssl/computer.key
declare -r node_configure_file=/etc/opt/slapos/slapos.cfg

declare -r slapos_ifname=slapboot-re6stnet-lo
declare -r ipv4_local_network=10.202.29.0/24
declare -r ipv6_local_address=2001:67c:1254:e:32::1
declare -r slapos_user_basename=slapboot-user

declare -r slapos_installer_software=http://git.erp5.org/gitweb/slapos.git/blob_plain/refs/heads/cygwin-share:/software/slapos-windows-installer/software.cfg
declare -r cygwin_home=$(cygpath -a $(cygpath -w /)\\.. | sed -e "s%/$%%")

# -----------------------------------------------------------
# Patch cygwin packages for building slapos
# -----------------------------------------------------------
csih_inform "Patching cygwin packages for building slapos"

csih_inform "libtool patched"
sed -i -e "s/4\.3\.4/4.5.3/g" /usr/bin/libtool

csih_inform "/etc/passwd generated"
[[ -f /etc/passwd ]] || mkpasswd > /etc/passwd

csih_inform "/etc/group generated"
[[ -f /etc/group ]] || mkgroup > /etc/group

_filename=$(cygpath -a -w $(cygpath -w /)\\..\\setup.exe)
csih_inform "check ${_filename}"
[[ -f $(cygpath -u ${_filename}) ]] || csih_error "missing ${_filename}"

_filename=/usr/bin/cygport
if [[ -f ${_filename} ]] ; then
    csih_inform "Patching ${_filename} ..."
    sed -i -e 's/D="${workdir}\/inst"/D="${CYGCONF_PREFIX-${workdir}\/inst}"/g' ${_filename} &&
    csih_inform "OK"
else
    csih_error "Missing cygport package, no ${_filename} found."
fi
_filename=/usr/share/cygport/cygclass/autotools.cygclass
if [[ -f ${_filename} ]] ; then
    csih_inform "Patching ${_filename} ..."
    sed -i -e 's/prefix=$(__host_prefix)/prefix=${CYGCONF_PREFIX-$(__host_prefix)}/g' ${_filename} &&
    csih_inform "OK"
else
    csih_error "Missing cygport package, no ${_filename} found."
fi
_filename=/usr/share/cygport/cygclass/cmake.cygclass
if [[ -f ${_filename} ]] ; then
    csih_inform "Patching ${_filename} ..."
    sed -i -e 's/-DCMAKE_INSTALL_PREFIX=$(__host_prefix)/-DCMAKE_INSTALL_PREFIX=${CYGCONF_PREFIX-$(__host_prefix)}/g' ${_filename} &&
    csih_inform "OK"
else
    csih_error "Missing cygport package, no ${_filename} found."
fi

for _cmdname in ip useradd usermod groupadd brctl tunctl ; do
    wget -c http://git.erp5.org/gitweb/slapos.package.git/blob_plain/heads/cygwin:/windows/scripts/${_cmdname} -O /usr/bin/${_cmdname} ||
    csih_error "download ${_cmdname} failed"
    csih_inform "download cygwin script ${_cmdname} OK"
    chmod +x /usr/bin/${_cmdname} || csih_error "chmod /usr/bin/${_cmdname} failed"
done

if check_os_is_wow64 ; then
    wget -c http://dashingsoft.com/products/slapos/ipwin_x64.exe -O /usr/bin/ipwin.exe ||
    csih_error "download ipwin_x64.exe failed"
    csih_inform "download ipwin_x64.exe OK"
else
    wget -c http://dashingsoft.com/products/slapos/ipwin_x86.exe -O /usr/bin/ipwin.exe ||
    csih_error "download ipwin_x86.exe failed"
    csih_inform "download ipwin_x86.exe OK"
fi
chmod +x /usr/bin/ipwin.exe || csih_error "chmod /usr/bin/ipwin.exe failed"

csih_inform "Patch cygwin packages for building slapos OK"
echo ""

# -----------------------------------------------------------
# Install network interface used by slapos node
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
# Run the buildout of slapos node
# -----------------------------------------------------------
csih_inform "Starting run buildout of slapos node ..."

csih_inform "mkdir /opt/slapos/log"
mkdir -p /opt/slapos/log

csih_inform "mkdir /opt/download-cache"
mkdir -p /opt/download-cache

[[ -f /opt/slapos/buildout.cfg ]] ||
(cd /opt/slapos && echo "[buildout]
extends = http://git.erp5.org/gitweb/slapos.git/blob_plain/refs/heads/cygwin-share:/component/slapos/buildout.cfg
download-cache = /opt/download-cache
prefix = ${buildout:directory}
" > buildout.cfg) &&
csih_inform "buildout.cfg generated"

[[ -f /opt/slapos/bootstrap.py ]] ||
(cd /opt/slapos &&
python -S -c 'import urllib2;print urllib2.urlopen("http://git.erp5.org/gitweb/slapos.core.git/blob_plain/HEAD:/bootstrap.py").read()' > bootstrap.py ) ||
csih_error "download bootstrap.py failed"
csih_inform "download bootstrap.py OK"

[[ -f /opt/slapos/bin/buildout ]] ||
(cd /opt/slapos && python -S bootstrap.py) ||
csih_error "run bootstrap.py failed"
csih_inform  "run bootstrap.py OK"

csih_inform "start bin/buildout"
(cd /opt/slapos ; bin/buildout -v -N) || csih_error "bin/buildout failed"

_filename=~/slapos-core-format.patch
wget -c http://git.erp5.org/gitweb/slapos.package.git/blob_plain/heads/cygwin:/windows/patches/slapos-core-format.patch -O ${_filename} ||
csih_error "download ${_filename} failed"
csih_inform "download ${_filename} OK"

csih_inform "applay patch ${_filename}"
(cd $(ls -d /opt/slapos/eggs/slapos.core-*.egg/) &&
csih_inform "patch at $(pwd)" &&
patch -f --dry-run -p1 < ${_filename} > /dev/null &&
patch -p1 < ${_filename} &&
csih_inform "apply patch ${_filename} OK")

csih_inform "Run buildout of slapos node OK"
echo ""

# -----------------------------------------------------------
# Configure slapos node and client
# -----------------------------------------------------------
csih_inform "Starting configure slapos client and node ..."

for _name in certificate key computer.key computer.crt ; do
    [[ -f ~/${_name} ]] || csih_error "missing file ~/${_name}"
done
for _name in test-computer.key test-computer.crt ; do
    [[ -f ${cygwin_home}/${_name} ]] || csih_error "missing file ${cygwin_home}/${_name}"
done
cp ~/certificate ${cygwin_home} && csih_inform "copy ~/certificate to ${cygwin_home}"
cp ~/key ${cygwin_home} && csih_inform "copy ~/key to ${cygwin_home}"

csih_inform "mkdir /etc/opt/slapos/ssl/partition_pki"
mkdir -p /etc/opt/slapos/ssl/partition_pki
csih_inform "mkdir ${slapos_client_home}"
mkdir -p ${slapos_client_home}

(cp ~/certificate ${client_certificate_file} &&
cp ~/key ${client_key_file} &&
cp ~/computer.crt ${node_certificate_file} &&
cp ~/computer.key ${node_key_file} &&
csih_inform "copy certificate/key files OK") ||
csih_error "copy certificate/key files failed"

computer_guid=$(grep "CN=COMP" ${node_certificate_file} | \
    sed -e "s/^.*, CN=//g" | sed -e "s%/emailAddress.*\$%%g")
[[ "${computer_guid}" == COMP-+([0-9]) ]] ||
csih_error_multi "${computer_guid} is invalid computer guid." \
    "It should like 'COMP-XXXX', edit ${node_certificate_file}" \
    "to fix it."
csih_inform "computer reference id: ${computer_guid}"

interface_guid=$(ipwin guid *msloop ${slapos_ifname}) ||
csih_error "get guid of interface ${slapos_ifname} failed"
[[ "$interface_guid" == {*-*-*-*} ]] ||
csih_error "invalid interface guid ${interface_guid} specified."
csih_inform "the guid of interface ${slapos_ifname} is ${interface_guid}"

wget -c http://git.erp5.org/gitweb/slapos.core.git/blob_plain/HEAD:/slapos.cfg.example -O ${node_configure_file} ||
csih_error "download ${node_configure_file} failed"
csih_inform "download ${node_configure_file} OK"
wget -c http://git.erp5.org/gitweb/slapos.core.git/blob_plain/HEAD:/slapos-client.cfg.example -O ${client_configure_file} ||
csih_error "download ${node_configure_file} failed"
csih_inform "download ${node_configure_file} OK"

csih_inform "ipv4_local_network is ${ipv4_local_network}"
sed -i  -e "s%^\\s*interface_name.*$%interface_name = ${interface_guid}%" \
        -e "s%^#\?\\s*ipv6_interface.*$%# ipv6_interface =%g" \
        -e "s%^ipv4_local_network.*$%ipv4_local_network = ${ipv4_local_network}%" \
        -e "s%^computer_id.*$%computer_id = ${computer_guid}%" \
        -e "s%^user_base_name =.*$%user_base_name = ${slapos_user_basename}%" \
        ${node_configure_file}
csih_inform "type ${node_configure_file}:"
csih_inform "************************************************************"
cat ${node_configure_file}
csih_inform "************************************************************"

sed -i -e "s%^cert_file.*$%cert_file = ${client_certificate_file}%" \
       -e "s%^key_file.*$%key_file = ${client_key_file}%" \
       ${client_configure_file}
csih_inform "type ${client_configure_file}:"
csih_inform "************************************************************"
cat ${client_configure_file}
csih_inform "************************************************************"

csih_inform "Configure slapos client and node OK"
echo ""

# -----------------------------------------------------------
# Format slapos node
# -----------------------------------------------------------
csih_inform "Formatting SlapOS Node ..."

netsh interface ipv6 add addr ${slapos_ifname} ${ipv6_local_address}
/opt/slapos/bin/slapos node format -cv --now ||
csih_error "Run slapos node format failed. "

echo ""

# -----------------------------------------------------------
# Request an instance of slapos installer software
# -----------------------------------------------------------
csih_inform "Supply slapos_installer_software in the ${computer_guid}"

csih_inform "  ${slapos_installer_software}"
/opt/slapos/bin/slapos supply ${slapos_installer_software} ${computer_guid}
_title="SlapOS-Windows-Installer-In-${computer_guid}"

csih_inform "Request an instance as ${_title}"
/opt/slapos/bin/slapos request ${client_configure_file} ${_title} \
    ${slapos_installer_software} --node computer_guid=${computer_guid}

echo ""

# -----------------------------------------------------------
# Enter loop to release software, create an instance, report
# -----------------------------------------------------------
while true ; do
    csih_inform "Releasing software ..."
    /opt/slapos/bin/slapos node software --verbose || continue

    csih_inform "Creating instance ..."
    /opt/slapos/bin/slapos node instance --verbose

    csih_inform "Sending report ..."
    /opt/slapos/bin/slapos node report --verbose

    /opt/slapos/bin/slapos request ${client_configure_file} ${_title} \
        ${slapos_installer_software} --node computer_guid=${computer_guid} &&
    break
done

echo ""
csih_inform "Bootstrip slapos node successfully."
echo ""

read -n 1 -t 60 -p "Press any key to exit..."
exit 0
