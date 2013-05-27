#! /bin/bash
#
# Configure slapos node,
#
#     1. Install re6stnet if it hasn't
#
#     2. Register to nexedi re6stnet
#
#     3. Install msloop network adapter, named to re6stnet-lo
#
#        It'll used as main interface for slapos and re6stnet
#
#     4. Create node configure file by parameters ca/key and computer id
#
#     5. Add init-slapos-node.sh as system startup item
#
# Usage:
#
#    ./slapos-node-config
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
    netsh interface ipv6 show interface $ifname | \
        grep "^GUID\s*:" | \
        sed -e "s/^GUID\s*:\s*//"
}

#
# Show error message and waiting for user to press any key quit
#
function show_error_exit()
{
    msg=${1-Configure node failed.}
    echo $msg
    read -n 1 -t 15 -p "Press any key to exit..."
    exit 1
}

node_certificate_file=/etc/opt/slapos/ssl/computer.crt
node_key_file=/etc/opt/slapos/ssl/computer.key
node_config_file=/etc/opt/slapos/slapos.cfg
node_template_file=/etc/slapos/slapos.cfg.example
run_key='\HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'
slapos_run_entry=SlapOS-Node
slapos_ifname=re6stnet-lo

# Remove startup item first.
regtool -q unset "$run_key\\$slapos_run_entry"

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

mkdir -p /etc/opt/slapos/ssl/partition_pki

if [[ "$1" == COMP-+([0-9]) ]] ; then
    computer_id=$1
else
    [[ "X$1" == "X" ]] || echo "Invalid computer id: $1"
    echo
    echo Please input computer id you have registered, it looks like COMP-XXXX
    read -p "computer id: " computer_id
fi
[[ "$computer_id" == COMP-+([0-9]) ]] || \
    show_error_exit "Invalid computer id specified."

if [[ -f "$2" ]] ; then
    echo "Copy certificate from $2 to $node_certificate_file"
    cp $2 $node_certificate_file
elif [[ ! -f $node_certificate_file ]] ; then
    read -p "Where is certificate file: " certificate_file
    [[ ! -f "$certificate_file" ]] && \
        show_error_exit "Certificate file $certificate_file doesn't exists."
    echo "Copy certificate from $certificate_file to $node_certificate_file"
    certificate_file=$(cygpath -u $certificate_file)
    cp $certificate_file $node_certificate_file
fi

if [[ -f "$3" ]] ; then
    echo "Copy key from $3 to $node_key_file"
    cp $3 $node_key_file
elif [[ ! -f $node_key_file ]] ; then
    read -p "Where is key file: " key_file
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

# Config slapproxy
if ! $(grep -q "^\[slapproxy\]" $node_config_file) ; then
    echo "
[slapproxy]
host = 127.0.0.1
port = 28080
database_uri = /var/lib/slapproxy.db
" >> $node_config_file
fi

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
# Add run item when windows startup
#
init_script=/etc/slapos/scripts/init-slapos-node
password_file=/etc/passwd
password_orig=/etc/slapos-format-passwd.orig
cygroot=$(cygpath -w -a /)
echo "Add ${init_script}.sh as Windows startup item."
[[ -f ${init_script}.bat ]] && cat <<EOF > ${init_script}.bat
@ECHO OFF
SETLOCAL

${cygroot:0:2}
CD "$(cygpath -w /usr/bin)"
.\cp $password_file $password_orig
.\sed -i -e "s/^Administrator:unused:500:513/Administrator:unused:0:513/" $password_file
START /B bash --login -i "${init_script}.sh"
.\sleep 3
.\cp $password_orig $password_file

ENDLOCAL
EXIT 0
EOF

# regtool -q set "$run_key\\$slapos_run_entry" \
#   "\"$(cygpath -w /usr/bin/bash)\" --login -i ${init_script}.sh" || \
#     show_error_exit "Add startup item failed."
regtool -q set "$run_key\\$slapos_run_entry" \
    "\"$(cygpath -w ${init_script}.bat)\"" || \
    show_error_exit "Add startup item failed."

echo SlapOS Node configure successfully.
read -n 1 -t 10 -p "Press any key to exit..."
exit 0
