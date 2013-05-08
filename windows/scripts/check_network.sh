#! /bin/bash
#
# It used to check the following network setting
#
#    1. Support IPv6 or not.
#
#    2. Is there network connection re6stnet-lo or not.
#
#    3. Make sure only one MSLOOP network adapter.
#
#    4. interface_name in the Node configure file is re6stnet-lo
#

function usage()
{
    echo Check network setting, usage:
    echo
    echo   check_network.sh [node_config_file]
    echo
    echo   The default node config file is /etc/opt/slapos/slapos.cfg
    echo
}

# Get connection name by GUID name, for example
#
#     $ guid2name {C8D7F065-AD35-4777-A768-122451282533}
#
function guid2name()
{
    if [[ "$1" == "" ]] ; then
        echo
    else
        netsh interface ipv6 show interface level=verbose | \
        grep -B 1 "$1" | \
        grep "^Connection" | \
        sed -e "s/^Connection Name\\s*:\\s*//g"
    fi
}

# Default node configure filename
node_config_file=${1-/etc/opt/slapos/slapos.cfg}

echo
echo "Checking IPv6 stack ..."
netsh interface ipv6 show interface > /dev/null
if (( $? )) ; then
    echo "Warning: No IPv6 installed."
    echo "Check IPv6 stack failed."
else
    echo "Check IPv6 stack OK."
fi
echo

echo
echo "Checking $node_config_file ..."
if [[ -f $node_config_file ]] ; then
    echo "Check node configure file OK."
    
    echo
    echo "Checking interface_name ..."
    interface=$(grep "^interface_name\\s*=" $node_config_file | \
                sed -e "s/^interface_name\\s*=\\s*//g")

    if (( $? == 0 )) ; then
        ifname=$(guid2name $interface)
        if [[ "$ifname" == "" ]]; then
            echo "Warning: no interface $interface found in your computer."
            echo "Check interface name failed."
        elif [[ "$ifname" == "re6stnet-lo" ]]; then
            echo "Check interface name OK."
        else
            echo "Warning: connection name of $interface is $ifname, " \
                  "expect it is re6stnet-lo."
            echo "Check interface name failed."
        fi
    else
        echo "Warning: no interface_name found in the $node_config_file"
        echo "Check interface name failed."
    fi
    echo

else
    echo "Warning: $node_config_file doesn't exists."
    echo "Check node configure file failed."
fi
echo

echo
echo "Checking duplicate MSLOOP network adapter ..."
local -i n=$(getmac /V /FO LIST | grep "Network Adapter:  Microsoft Loopback Adapter" | wc -l)
(( n > 1 )) && echo "More than one MSLOOP network adapter found. Be ware all of them share one same MAC Address, thus same IPv6 link address!"
echo
