#!/bin/sh -e

# This Script automates the the setup of SLAPOS Servers with
# Essential information.

if [ -z "$COMPUTERNAME" ]; then
  echo " [ERROR] Please export COMPUTERNAME= variable, and rerun the script, it is mandatory for slapos"
  exit 1
fi

if [ ! -f /etc/apt/sources.list.d/git.erp5.org.list ]; then
  gpg --keyserver subkeys.pgp.net --recv-keys 1A716324
  gpg --export 1A716324 | apt-key add -

  echo "deb http://git.erp5.org/dist/deb ./" > /etc/apt/sources.list.d/git.erp5.org.list
fi

if [ ! -f /etc/apt/sources.list.d/slapos.list ]; then 
  echo "deb http://download.opensuse.org/repositories/home:/VIFIBnexedi/Debian_7.0/ ./" | tee /etc/apt/sources.list.d/slapos.list
  wget -O- "http://download.opensuse.org/repositories/home:/VIFIBnexedi/Debian_7.0/Release.key" | apt-key add -
fi

apt-get update
apt-get install -y slapos-node re6stnet

echo "[HACKING] Fixing Package ..."
rm  -rf /etc/openvpn/vifi*
rm -rf /etc/opt/slapos/openvpn-needed

service openvpn restart 

sed -i "/tapVPN/d" /etc/cron.d/slapos-node

if [ ! -f /etc/re6stnet/re6stnet.conf ]; then
  # Register re6stnet.
  re6st-conf --registry http://re6stnet.nexedi.com/ -r title $COMPUTERNAME -d /etc/re6stnet --anonymous

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
while [[ $? != 0 ]] && [[ $i < $IPV6WAITTIME ]]
do
    let i++
    sleep 1
    ping6 -c 2 ipv6.google.com
done
set -e

if [ ! -f /etc/opt/slapos/slapos.cfg ]; then
  slapos node register $COMPUTERNAME --partition-number 20 --ipv6-interface lo --interface-name eth0
fi

# Create PKI repository
if [ ! -f /etc/opt/slapos/slapos.cfg ]; then
 echo """ /etc/opt/slapos/slapos.cfg don't exist, so we don't progress on tweak """
 exit 1
fi

cat > /usr/local/sbin/slapos-tweak << EOF
#!/bin/sh -e

mkdir -v -p -m 0755 `grep ^certificate_repository_path /etc/opt/slapos/slapos.cfg | sed 's/^certificate_repository_path.*= *//'` 

grep ^computer_id /etc/opt/slapos/slapos.cfg | sed 's/^computer_id.*= *//' > /etc/hostname
hostname -F /etc/hostname

echo """ [SERVER TWEAK] Set sysctl, load kvm_intel and other modules."""

# Setup more server like network parameters in order to avoid
#    "Neighbour table overflow."
# Those machines are itself has a lot of interfaces and are in
# heavily networked environment, so limit of ARP cache for IPv4
# and IPv6 is 4x higher then default
# More tuning can be applied from: http://www.enigma.id.au/linux_tuning.txt
sysctl -w \
  net.ipv4.neigh.default.gc_thresh1=512 \
  net.ipv4.neigh.default.gc_thresh2=1024 \
  net.ipv4.neigh.default.gc_thresh3=2048 \
  net.ipv6.neigh.default.gc_thresh1=512 \
  net.ipv6.neigh.default.gc_thresh2=1024 \
  net.ipv6.neigh.default.gc_thresh3=2048

# Increase default aio-max-nr for sql servers
sysctl -w fs.aio-max-nr=16777216
# Increase semaphore limits
sysctl -w kernel.sem="1250 256000 100 1024"

# Force reboot after kernel panic
sysctl -w kernel.panic=120

# Yes we hardcode this here for debian
e2label /dev/sda1 SLAPOS

# Enable noop scheduler for disk which have SLAPOS labeled partition
disk=\`blkid -L SLAPOS | sed -r -e 's/(\/dev\/|[0-9]*$)//g'\`
echo noop > /sys/block/\$disk/queue/scheduler

# Set kvm up
modprobe kvm_intel
sleep 1
chmod 666 /dev/kvm

# Set power saving
modprobe acpi_cpufreq > /dev/null  2>&1

# Set hardware monitoring tools (for Shuttle xh61 machines)
modprobe coretemp > /dev/null  2>&1
modprobe f71882fg > /dev/null  2>&1

# Activate KSM (shared memory for KVM)
echo 1 > /sys/kernel/mm/ksm/run

slapos format --now

EOF

chmod a+x /usr/local/sbin/slapos-tweak
slapos-tweak

cat > /etc/cron.d/slapos-boot << EOF
SHELL=/bin/sh
PATH=/usr/bin:/usr/sbin:/sbin:/bin
MAILTO=""

@reboot root slapos-tweak
@reboot root /opt/slapos/bin/bang /etc/opt/slapos/slapos.cfg -m "Reboot." 

EOF

