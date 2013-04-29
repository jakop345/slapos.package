#! /bin/bash

function guid2name()
{
    if [[ "$1" == "" ]] ; then
        echo
    else
        netsh interface ipv6 show interface level=verbose | \
        grep -B 1 "{C8D7F065-AD35-4777-A768-122451282533}" | \
        grep "^Connection" | \
        sed -e "s/^Connection Name\\s*:\\s*//g"
    fi
}

cfilename=/etc/opt/slapos/slapos.cfg

if [[ ! -f $cfilename ]] ; then
    echo "Error: no found configure file $cfilename, the computer "
    echo "need register as a SlapOS Node first."
    exit 1
fi

interface=$(grep "^interface_name\\s*=" $cfilename | sed -e "s/^interface_name\\s*=\\s*//g")
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
cd /etc/re6stnet
re6stnet @re6stnet.conf -I $ifname -i $ifname

echo Waiting Re6stent network work ...
while true ; do
  ping6 slap.vifib.com > /dev/null && break
done

if (( $? == 0 )) ; then
    echo Re6stnet network OK.
else
    echo SlapOS Node initialize failed, no any IPv6 connection.
    exit 1
fi

/opt/slapos/bin/slapformat -c --now /etc/opt/slapos/slapos.cfg
