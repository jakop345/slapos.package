#! /bin/bash
#
# It used to initialzie slapos node when the computer startup:
#
#    1. Start re6stnet, 
#
#    2. Run slapformat to synchornize information with master
#
#    3. Start slapproxy
#
#    4. 
#    
export PATH=/usr/local/bin:/usr/bin:$PATH

ifname=re6stnet-lo

# Run re6stnet
echo "Start re6stnet ..."
(cd /etc/re6stnet; re6stnet @re6stnet.conf -I $ifname -i $ifname &)
echo "Start re6stent (pid:$!)in the background OK."

# echo "Waiting re6stent network work ..."
# while true ; do
#   ping6 slap.vifib.com > /dev/null && break
# done
# echo "re6stnet network OK."

# Run slapformat
echo "Initializing SlapOS Node ..."
/opt/slapos/bin/slapos node format -c --now
if (( $? )) ; then
    echo "Initialize SlapOS Node failed."
else
    echo "Initialize SlapOS Node OK."
fi

# Run slapproxy
# /opt/slapos/bin/slapproxy || echo "Start slapproxy failed."

exit 0
