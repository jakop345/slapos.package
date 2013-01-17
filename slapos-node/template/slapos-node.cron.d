SHELL=/bin/sh
PATH=/usr/bin:/usr/sbin:/sbin:/bin
MAILTO=root

# Run "Installation/Destruction of Software Releases" and "Deploy/Start/Stop Partitions" once per minute
* * * * * root /opt/slapos/bin/slapos node software --verbose --logfile=/opt/slapos/slapos-software.log
* * * * * root /opt/slapos/bin/slapos node instance --verbose --logfile=/opt/slapos/slapos-instance.log

# Run "Destroy Partitions to be destroyed" once per hour
0 * * * * root /opt/slapos/bin/slapos node report --maximal_delay=3600 --verbose --logfile=/opt/slapos/slapos-report.log

# Run "Check/add IPs and so on" once per hour
0 * * * * root /opt/slapos/bin/slapos node format >> /opt/slapos/slapos-format.log 2>&1


# Make sure we have only good network routes if we use VPN
* * * * * root if [ -f /etc/opt/slapos/openvpn-needed  ]; then ifconfig tapVPN | grep "Scope:Global" > /dev/null ;if [ $? = 0 ]; then ROUTES=$(ip -6 r l | grep default | awk '{print $5}'); for GW in $ROUTES ; do if [ ! $GW = tapVPN ]; then /sbin/ip -6 route del default dev $GW;fi ;done ;fi ;fi
