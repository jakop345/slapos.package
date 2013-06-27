#! /bin/bash
#
# Configure slapos node, it could be run at anytime to check the
# configure of slapos node. The main functions:
#
#     * Install msloop network adapter, named to re6stnet-lo
#
#        It'll used as main interface for slapos and re6stnet
#
#     * ipv6: Ipv6 configure
#
#     * re6stnet: Install re6stnet and register to nexedi re6stnet if it hasn't
#
#     * node: Create node configure file by parameters ca/key
#
#     * client: Create client configure file by parameters ca/key
#
#     * cron: start/stop cron configure.
#
# Usage:
#
#    ./slapos-node-config [ * | ipv6 | re6stnet | node | client | cron ]
#
export PATH=/usr/local/bin:/usr/bin:$PATH

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
    # This command doesn't work in the Windows 7/8, maybe Vista
    # netsh interface ipv6 show interface $ifname | \
    #     grep "^GUID\s*:" | \
    #     sed -e "s/^GUID\s*:\s*//"
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
#   query_parameter Actual Excpeted Message
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

slapos_client_home=~/.slapos
client_configure_file=$slapos_client_home/slapos.cfg
client_certificate_file=$slapos_client_home/certificate
client_key_file=$slapos_client_home/key
client_template_file=/etc/slapos/slapos-client.cfg.example

node_certificate_file=/etc/opt/slapos/ssl/computer.crt
node_key_file=/etc/opt/slapos/ssl/computer.key
node_config_file=/etc/opt/slapos/slapos.cfg
node_template_file=/etc/slapos/slapos.cfg.example
run_key='\HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'
slapos_run_entry=SlapOS-Node
slapos_ifname=re6stnet-lo

mkdir -p /etc/opt/slapos/ssl/partition_pki
mkdir -p $slapos_client_home

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
reset_connection $slapos_ifname
echo SlapOS network adapter OK.

#
# Generate Node Configure file
#
echo
echo Before continue to configure, make sure you have register your server to
echo slapos.org community Cloud, and have obtained X509 certificate and key
echo which are needed for the following configuration process.
echo
echo Refer to http://community.slapos.org/wiki/osoe-Lecture.SlapOS.Extended/developer-Installing.SlapOS.Slave.Node.Source
echo

if [[ ! -f $node_certificate_file ]] ; then
    read -p "Where is computer certificate file: " certificate_file
    [[ ! -f "$certificate_file" ]] && \
        show_error_exit "Certificate file $certificate_file doesn't exists."
    echo "Copy certificate from $certificate_file to $node_certificate_file"
    certificate_file=$(cygpath -u $certificate_file)
    cp $certificate_file $node_certificate_file
fi

computer_id=$(grep  CN=COMP $node_certificate_file | sed -e "s/^.*, CN=//g" | sed -e "s%/emailAddress.*\$%%g")
[[ "$computer_id" == COMP-+([0-9]) ]] || \
    show_error_exit "Invalid computer id specified."
echo Computer GUID is: $computer_id

if [[ ! -f $node_key_file ]] ; then
    read -p "Where is computer key file: " key_file
    [[ ! -f "$key_file" ]] && \
        show_error_exit "Key file $key_file doesn't exists."
    echo "Copy key from $key_file to $node_key_file"
    key_file=$(cygpath -u $key_file)
    cp $key_file $node_key_file
fi

# Hope it will not confilct with original network in the local machine
ipv4_local_network=10.201.67.0/24

# Add ipv4 address
ip -4 addr add $ipv4_local_network dev $slapos_ifname

# Create node configure file, replace interface_name with guid of
# re6stnet-lo

if [[ ! -f $node_config_file ]] ; then
    [[ -f $node_template_file ]] || \
        (cd /etc/slapos; wget http://git.erp5.org/gitweb/slapos.core.git/blob_plain/HEAD:/slapos.cfg.example) || \
        show_error_exit "Download slapos.cfg.example failed."
    cp $node_template_file $node_config_file
fi

interface_guid=$(connection2guid $slapos_ifname)
# generate /etc/slapos/slapos.cfg
sed -i  -e "s%^\\s*interface_name.*$%interface_name = $interface_guid%" \
        -e "s%^#\?\\s*ipv6_interface.*$%# ipv6_interface =%g" \
        -e "s%^ipv4_local_network.*$%ipv4_local_network = $ipv4_local_network%" \
        -e "s%^computer_id.*$%computer_id = $computer_id%" \
        $node_config_file

if [[ ! -f $client_certificate_file ]] ; then
    read -p "Where is user certificate file: " certificate_file
    [[ ! -f "$certificate_file" ]] && \
        show_error_exit "Certificate file $certificate_file doesn't exists."
    echo "Copy certificate from $certificate_file to $client_certificate_file"
    certificate_file=$(cygpath -u $certificate_file)
    cp $certificate_file $client_certificate_file
fi

if [[ ! -f $client_key_file ]] ; then
    read -p "Where is user key file: " key_file
    [[ ! -f "$key_file" ]] && \
        show_error_exit "Key file $key_file doesn't exists."
    echo "Copy key from $key_file to $client_key_file"
    key_file=$(cygpath -u $key_file)
    cp $key_file $client_key_file
fi

if [[ ! -f $client_configure_file ]] ; then
    [[ -f $template_configure_file ]] || \
        (cd /etc/slapos; wget http://git.erp5.org/gitweb/slapos.core.git/blob_plain/HEAD:/slapos-client.cfg.example) || \
        show_error_exit "Download slapos-client.cfg.example failed."
    cp $template_configure_file $client_configure_file
fi

sed -i -e "s%^cert_file.*$%cert_file = $client_certificate_file%" \
       -e "s%^key_file.*$%key_file = $client_key_file%" \
       $client_configure_file

#
# Re6stnet
#

# Check ipv6, install it if it isn't installed.
netsh interface ipv6 show interface > /dev/null || netsh interface ipv6 install

# miniupnpc is required by re6stnet
if [[ ! -d /opt/miniupnpc ]] ; then
    if [[ -f /miniupnpc.tar.gz ]] ; then
        echo "Installing miniupnpc ..."
        cd /opt
        tar xzf /miniupnpc.tar.gz --no-same-owner
        mv $(ls -d miniupnpc-*) miniupnpc
        cd miniupnpc
        make
        python setup.py install || echo "Install miniupnpc failed."
    else
        echo "No miniupnpc source package found."
    fi
fi

# pyOpenSSL is required by re6stnet
if [[ ! -d /opt/pyOpenSSL ]] ; then
    if [[ -f /pyOpenSSL.tar.gz ]] ; then
        echo "Installing pyOpenSSL ..."
        cd /opt
        tar xzf /pyOpenSSL.tar.gz --no-same-owner
        mv $(ls -d pyOpenSSL-*) pyOpenSSL
        cd pyOpenSSL
        python setup.py install || echo "Install pyOpenSSL failed."
    fi
fi

# Install re6stnet
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
    python setup.py install || echo "Install re6stnet failed."
fi

mkdir -p /etc/re6stnet
cd /etc/re6stnet
if [[ ! -f re6stnet.conf ]] ; then
    re6st-conf --registry http://re6stnet.nexedi.com/
fi
[[ ! -f re6stnet.conf ]] && show_error_exit "Register to nexedi re6stnet failed"
grep -q "^table " re6stnet.conf || echo "table 0" >> re6stnet.conf

#
# Create instance of web runner
#
slaprunner_cfg=http://git.erp5.org/gitweb/slapos.git/blob_plain/refs/heads/cygwin-0:/software/slaprunner/software.cfg
while true ; do
    /opt/slapos/bin/slapos supply  $slaprunner_cfg $computer_id
    /opt/slapos/bin/slapos request "Node Runner" $slaprunner_cfg --node computer_guid=$computer_id && break
done
#
# Get url from connection infromation
# 
# Connection parameters of instance are:
#  {'backend_url': 'http://[2001:67c:1254:45::c5d5]:50000',
#  'cloud9-url': 'http://localhost:9999',
#  'password_recovery_code': 'e2d01c14',
#  'ssh_command': 'ssh 2001:67c:1254:45::c5d5 -p 2222',
#  'url': 'http://softinst39090.host.vifib.net/'}
slaprunner_url=$(/opt/slapos/bin/slapos request "Node Runner" $slaprunner_cfg --node computer_guid=$computer_id | grep backend_url | sed -e "s/^.*': '//g" -e "s/',.*$//g")

echo SlapOS Node configure successfully.
read -n 1 -p "Press any key to exit..."
exit 0
