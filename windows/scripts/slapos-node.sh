#! /bin/bash
export PATH=/usr/local/bin:/usr/bin:$PATH

ifname=re6stnet-lo

ping6 slap.vifib.com > /dev/null
# Run re6stnet if no native ipv6
if (( $? )) ; then
    echo "Start re6stnet ..."
    (cd /etc/re6stnet; re6stnet @re6stnet.conf --ovpnlog -I $ifname -i $ifname &)
    echo "Start re6stent in the background OK."

    echo "Waiting re6stent network work ..."
    while true ; do
        ping6 slap.vifib.com && break
    done
    echo "re6stnet network OK."
fi

# Format slapos node
echo "Run Slapos format ..."
/opt/slapos/bin/slapos node format -cv --now
if (( $? )) ; then
    echo "Failed to run slapos format."
    exit 1
else
    echo "Format slapos node OK."
fi

# Release software
echo "Releasing software ..."
/opt/slapos/bin/slapos node software
if (( $? )) ; then
    echo "Failed to relase software in the slapos node."
    exit 1
else
    echo "Release software OK." 
fi

# Instance software
echo "Creating instance ..."
/opt/slapos/bin/slapos node instance
if (( $? )) ; then
    echo "Failed to create instance in the slapos node."
    exit 1
else
    echo "Create instance OK." 
fi

# Send report
/opt/slapos/bin/slapos node report

exit 0
