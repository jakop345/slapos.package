#!/bin/sh -e

# This Script automates the the setup of SLAPOS Servers with
# Essential information.

if [ -z "$COMPUTERNAME" ]; then
  echo " [ERROR] Please export COMPUTERNAME= variable, and rerun the script, it is mandatory for slapos"
  exit 1
fi

if [ -z "$SLAPPKGKEY" ]; then
  SLAPPKGKEY=slapos-update-v0-iePo8Patho4aejai2reew1cai7exeibiepa8winideefar3aiBoh8ohpaingieTh
fi

if [ ! -f /usr/local/bin/slappkg-update ]; then
  apt-get install -y python-setuptools openssl
  easy_install -U slapos.package
fi

slappkg-conf --key=$SLAPPKGKEY 

slappkg-update 

# Firmware for realtek
apt-get install -y firmware-realtek 

if [ ! -f /etc/re6stnet/re6stnet.conf ]; then

  re6st-conf -d /etc/re6stnet --registry "http://re6stnet.nexedi.com" -r title $COMPUTERNAME --anonymous

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

if [ ! -f /etc/opt/slapos/slapos.cfg ]; then
  slapos node register $COMPUTERNAME --partition-number 20 --interface-name lo
fi

if [ ! -f /etc/opt/slapos/slapos.cfg ]; then
 echo """ /etc/opt/slapos/slapos.cfg don't exist, so we don't progress on tweak """
 exit 1
fi

slapos node boot

# slapos-tweak should be merged with slapos.package
slapos-tweak

cat > /etc/cron.d/slapos-boot << EOF
SHELL=/bin/sh
PATH=/usr/bin:/usr/sbin:/sbin:/bin
MAILTO=""

@reboot root /usr/sbin/slapos-tweak >> /opt/slapos/log/slapos-tweak.log 2>&1

EOF
