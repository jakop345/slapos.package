#!/bin/sh -e

# This Script automates the the setup of SLAPOS Servers with
# Essential information.

if [ -z "$COMPUTERNAME" ]; then
  echo " [ERROR] Please export COMPUTERNAME= variable, and rerun the script, it is mandatory for slapos"
  exit 1
fi

if [ ! -f /etc/apt/sources.list.d/slapos.list ]; then 
  echo "deb http://download.opensuse.org/repositories/home:/VIFIBnexedi/Debian_7.0/ ./" | tee /etc/apt/sources.list.d/slapos.list
  wget -O- "http://download.opensuse.org/repositories/home:/VIFIBnexedi/Debian_7.0/Release.key" | apt-key add -
fi

apt-get update
apt-get install -y ntp slapos-node

if [ ! -f /etc/re6stnet/re6stnet.conf ]; then
  slapos-re6st-setup $COMPUTERNAME

  /etc/init.d/re6stnet restart

  sleep 2

  echo "table 0" >> /etc/re6stnet/re6stnet.conf
  echo "interface eth0" >> /etc/re6stnet/re6stnet.conf

  # Restart service
  /etc/init.d/re6stnet restart

  echo "########################################################################"
  echo "Generated Configuration, please check if interface eth0 is consistent..."
  cat /etc/re6stnet/re6stnet.conf
  echo "########################################################################"
fi

set +e

IPV6WAITTIME=5
# Wait for native ipv6 connection to be ready 
i=0
ping6 -c 2 ipv6.google.com
while [ $? != 0 ] && [ $i < $IPV6WAITTIME ]
do
    let i++
    sleep 1
    ping6 -c 2 ipv6.google.com
done
set -e

if [ ! -f /etc/opt/slapos/slapos.cfg ]; then
  slapos node register $COMPUTERNAME --partition-number 20 --ipv6-interface lo --interface-name eth0
fi

if [ ! -f /etc/opt/slapos/slapos.cfg ]; then
 echo """ /etc/opt/slapos/slapos.cfg don't exist, so we don't progress on tweak """
 exit 1
fi

slapos-tweak

cat > /etc/cron.d/slapos-boot << EOF
SHELL=/bin/sh
PATH=/usr/bin:/usr/sbin:/sbin:/bin
MAILTO=""

@reboot root /usr/sbin/slapos-tweak >> /opt/slapos/log/slapos-tweak.log 2>&1
@reboot root /opt/slapos/bin/bang /etc/opt/slapos/slapos.cfg -m "Reboot." >> /opt/slapos/log/slapos-tweak.log 2>&1

EOF

