#!/bin/sh -e

# This Script automates the the setup of SLAPOS Servers with
# Essential information.

if [ -z "$COMPUTERNAME" ]; then
  echo " [ERROR] Please export COMPUTERNAME= variable, and rerun the script, it is mandatory for slapos"
  exit 1
fi

if [ ! -f /etc/slapos-aptget-flag ]; then 
  wget -O- "http://download.opensuse.org/repositories/home:/VIFIBnexedi/Debian_7.0/Release.key" | apt-key add -
  gpg --keyserver subkeys.pgp.net --recv-keys 1A716324
  gpg --export 1A716324 | apt-key add -
  touch /etc/slapos-aptget-flag
fi

if [ ! -f /usr/local/bin/slappkg-update ]; then
  apt-get install python-setuptools
  easy_install -U slapos.package
fi

slappkg-conf --key=slapos-update-v0-iePo8Patho4aejai2reew1cai7exeibiepa8winideefar3aiBoh8ohpaingieTh --slapos-configuration=/etc/opt/update.cfg

slappkg-update --slapos-configuration=/etc/opt/update.cfg

# Firmware for realtek
apt-get install -y firmware-realtek 

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
  rm /etc/opt/update.cfg
  slappkg-conf --key=slapos-update-v0-iePo8Patho4aejai2reew1cai7exeibiepa8winideefar3aiBoh8ohpaingieTh --slapos-configuration=/etc/opt/update.cfg
fi

if [ ! -f /etc/opt/slapos/slapos.cfg ]; then
 echo """ /etc/opt/slapos/slapos.cfg don't exist, so we don't progress on tweak """
 exit 1
fi

# slapos-tweak should be merged with slapos.package
slapos-tweak

cat > /etc/cron.d/slapos-boot << EOF
SHELL=/bin/sh
PATH=/usr/bin:/usr/sbin:/sbin:/bin
MAILTO=""

@reboot root /usr/sbin/slapos-tweak >> /opt/slapos/log/slapos-tweak.log 2>&1

EOF

