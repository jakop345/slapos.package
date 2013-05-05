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
    original_connections="$* X"
    current_connections=$(get_all_connections)
    
    for name in $current_connections ; do
        [[ "$original_connections" == ".* $name .*" ]] && \
        echo ${name//%/ /} && return 0
    done
}

#
# Remove all ipv4/ipv6 addresses in the connection re6stnet-lo
#
function reset_connection()
{
    ifname=${1-re6stnet-lo}
    for addr in $(netsh interface ipv6 show address $ifname level=normal | \
                grep "^Manual" \
                sed -e "s/^\(\w\+\s\+\)\{4\}//") ; do
        netsh interface ipv6 del address $ifname $addr
    done
    for addr in $(netsh interface ip show address $ifname | \
                grep "IP Address:" \
                sed -e "s/IP Address://") ; do
        netsh interface del address $ifname $addr
    done
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

# Remove startup item first.
run_key='\HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'
slapos_run_entry=SlapOS-Node
regtool -q unset "$run_key\\$slapos_run_entry"

#
# Add msloop network adapter, ane name it as "re6stnet-lo"
#
original_connections=$(get_all_connections)
if [[ ! "$original_connections X" == ".*\bre6stnet-lo\b.*X" ; then
    devcon install $WINDIR\\inf\\netloop.inf *MSLOOP
    connection_name=$(get_new_connection $original_connections)
    [[ "X$connection_name" == "X" ]] && \
        echo "Add msloop network adapter failed." && \
        exit 1
    netsh interface set interface "$connection_name" newname=re6stnet-lo
fi
reset_connection re6stnet-lo

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

if [[ "X$1" == "XCOMP-[0-9]+" ]] ; then
    computer_id=$1
else
    [[ "X$1" == "X" ]] || echo "Invalid computer id: $1"
    echo
    echo Please input computer id you have registered, it looks like COMP-XXXX
    read -p "computer id: " computer_id
fi
[[ "X$computer_id" == "XCOMP-[0-9]+" ]] || \
    (echo "Invalid computer id specified."; exit 1)

node_certificate_file=/etc/opt/slapos/ssl/certificate
if [[ -f "$2" ]] ; then
    echo "Copy certificate from $2 to $node_certificate_file"
    cp $2 $node_certificate_file
elif [[ ! -f $node_certificate_file ]] ; then
    read -p "Where is certificate file: " certificate_file
    [[ ! -f "$certificate_file" ]] && \
        echo "Certificate file %s doesn't exists." && exit 1
    echo "Copy certificate from $certificate_file to $node_certificate_file"
    cp $certificate_file $node_certificate_file    
fi

node_key_file=/etc/opt/slapos/ssl/key
if [[ -f "$3" ]] ; then
    echo "Copy key from $3 to $node_key_file"
    cp $3 $node_key_file
elif [[ ! -f $node_key_file ]] ; then
    read -p "Where is key file: " key_file
    [[ ! -f "$key_file" ]] && \
        echo "Key file %s doesn't exists." && exit 1
    echo "Copy key from $key_file to $node_key_file"
    cp $key_file $node_key_file    
fi

# Hope it will not confilct with original network in the local machine
ipv4_local_network=10.201.67.0/8

# Add ipv4 address
ip -4 addr $ipv4_local_network dev re6stnet-lo

# Create node configure file, replace interface_name with guid of
# re6stnet-lo
mkdir -p /etc/opt/slapos/ssl/partition_pki
nodecfgfile=/etc/opt/slapos/slapos.cfg

if [[ ! -f $nodecfgfile ]] ; then
    [[ -f /etc/slapos/slapos.cfg.sample ]] || \
        (cd /etc/slapos; wget -O slapos.cfg http://git.erp5.org/gitweb/slapos.core.git/blob_plain/HEAD:/slapos.cfg.example) || \
        (echo "Download slapos.cfg.example failed."; exit 1)
    
    cp /etc/slapos/slapos.cfg.sample $nodecfgfile
fi

interface_guid=$(connection2guid re6stnet-lo)
# generate /etc/slapos/slapos.cfg
sed -i  -e "s/^\\s*interface_name.*$/interface_name = $interface_guid/" \
        -e "s/^#\?\\s*ipv6_interface.*$/# ipv6_interface =/g" \
        -e "s/^ipv4_local_network.*$/ipv4_local_network = $ipv4_local_network/" \
        -e "s/^computer_id.*$/computer_id = $computer_id/" \
        $nodecfgfile

#
# Re6stnet
#

# Check ipv6, install it if it isn't installed.
netsh interface ipv6 show interface > /dev/null || netsh interface ipv6 install

# miniupnpc is required by re6stnet
if [[ ! -f /opt/miniupnpc ]] ; then
    cd /opt
    if [[ -f /miniupnpc.tar.gz ]] ; then
        tar xzf miniupnpc.tar.gz
        mv $(ls miniupnpc-*) miniupnpc
        cd miniupnpc
        python setup.py install || echo "Install miniupnpc failed."
    fi
fi

# Install re6stnet
if [[ ! -f /opt/re6stnet ]] ; then
    cd /opt
    if [[ -f /re6stnet.tar.gz ]] ; then
        tar xzf re6stnet.tar.gz
        mv $(ls re6stnet-*) re6stnet
    else
        git clone -b cygwin -n http://git.erp5.org/repos/re6stnet.git 
    fi
    cd re6stnet
    python setup.py install || echo "Install re6stnet failed."
fi

mkdir -p /etc/re6stnet
cd /etc/re6stnet
if [[ ! -f re6stnet.conf ]] ; then
    re6st-conf --registry http://re6stnet.nexedi.com/
fi
[[ ! -f re6stnet.conf ]] && echo "Register to nexedi re6stnet failed" && exit 1

# 
# Add run item when windows startup
#
init_script_name=/etc/slapos/scripts/init-salpos-node
echo "Add ${init_script_name}.sh as Windows startup item."
if [[ ! -f ${init_script_name}.bat ]] ; then
            cat <<EOF > ${init_script_name}.bat
\"$(cygpath -w /usr/bin/sh)\" --login -i ${init_script_name}.sh
EXIT 0
EOF
fi

regtool -q set "$run_key\\$slapos_run_entry" \
               "START \"$(cygpath -w ${init_script_name}.bat)" || \
echo "Add startup item failed."
