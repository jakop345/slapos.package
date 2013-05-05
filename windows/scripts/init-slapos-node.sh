#! /bin/bash
#
# It used to initialzie slapos node when the computer startup:
#
#    1. Start re6stnet, 
#
#    2. Check whether IPv6 connection is availabe
#
#    3. Run slapformat to synchornize information with master
#
#    4. Start slapproxy, it will used by slapos desktop and node manager
#    

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
cfilename=${1-/etc/opt/slapos/slapos.cfg}

if [[ ! -f $cfilename ]] ; then
    echo "Error: no found configure file $cfilename, the computer "
    echo "need register as a SlapOS Node first."
    exit 1
fi

interface=$(grep "^interface_name\\s*=" $cfilename | \
          sed -e "s/^interface_name\\s*=\\s*//g")
if (( $? == 0 )) ; then
    ifname=$(guid2name $interface)
else
    echo "Error: no interface found in the configure file $cfilename"
    exit 1
fi
if [[ "$ifname" == "" ]]; then
    echo "Error: no ipv6 interface found in the configure file $cfilename"
    exit 1
fi

# Run re6stnet, waiting until it works
cd /etc/re6stnet
re6stnet @re6stnet.conf -I $ifname -i $ifname

echo "Waiting re6stent network work ..."
while true ; do
  ping6 slap.vifib.com > /dev/null && break
done
echo "re6stnet network OK."

# Run slapformat
/opt/slapos/bin/slapos node format -cv --now || \
( echo "Initialize SlapOS Node failed."; exit 1 )
echo "Initialize SlapOS Node OK."

# Run slapproxy
/opt/slapos/bin/slapproxy || echo "Start slapproxy failed."
