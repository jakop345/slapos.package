SHELL=/bin/sh
PATH=/usr/bin:/usr/sbin:/sbin:/bin
MAILTO=""

# Run "Installation/Destruction of Software Releases" and "Deploy/Start/Stop Partitions" once per minute
* * * * * root /opt/slapos/bin/slapos node software --maximal_delay=30 --verbose --logfile=/opt/slapos/log/slapos-node-software.log > /dev/null 2>&1
* * * * * root /opt/slapos/bin/slapos node instance --maximal_delay=20 --promise-timeout 20 --verbose --logfile=/opt/slapos/log/slapos-node-instance.log > /dev/null 2>&1

# Run "Destroy Partitions to be destroyed" once per hour
0 * * * * root /opt/slapos/bin/slapos node report --maximal_delay=3600 --verbose --logfile=/opt/slapos/log/slapos-node-report.log > /dev/null 2>&1

# Run "Check/add IPs and so on" once per hour
0 * * * * root /opt/slapos/bin/slapos node format >> /opt/slapos/log/slapos-node-format.log 2>&1

# Run "Booting" on every system start
@reboot root /opt/slapos/bin/slapos node boot >> /opt/slapos/log/slapos-node-format.log 2>&1

# Run "Collect" once a minute
* * * * * root /opt/slapos/bin/slapos node collect >> /opt/slapos/log/slapos-node-collect.log 2>&1
