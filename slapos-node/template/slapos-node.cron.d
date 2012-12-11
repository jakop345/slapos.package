SHELL=/bin/sh
PATH=/usr/bin:/usr/sbin:/sbin:/bin
MAILTO=root

* * * * * root /opt/slapos/bin/slapos node software --verbose --logfile=/opt/slapos/slapos-software.log
* * * * * root /opt/slapos/bin/slapos node instance --verbose --logfile=/opt/slapos/slapos-instance.log

# slapgrid-ur: hardcoded script to rerun slapgrid-ur if failed.
SLAPOS_REPORT_COMMAND="/opt/slapos/bin/slapos node report --maximal_delay=3600 --verbose --logfile=/opt/slapos/slapos-report.log"
0 * * * * root $SLAPOS_REPORT_COMMAND; i=20; while [ $? != 0 ]; do SLAPOS_REPORT_COMMAND; sleep $(($i*60)); if [ $i < 20 ]; then let i++; fi; done;

0 * * * * root /opt/slapos/bin/slapos node format >> /opt/slapos/slapformat.log 2>&1

* * * * * root if [ -f /etc/opt/slapos/openvpn-needed  ]; then ifconfig tapVPN | grep "Scope:Global" > /dev/null ;if [ $? = 0 ]; then ROUTES=$(ip -6 r l | grep default | awk '{print $5}'); for GW in $ROUTES ; do if [ ! $GW = tapVPN ]; then /sbin/ip -6 route del default dev $GW;fi ;done ;fi ;fi
