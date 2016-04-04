
cat << EOF > /root/run-test
#!/bin/bash

BOOTSTRAP="/root/start-bootstrap"
FILE="/etc/cron.d/ansible-vm-bootstrap"
if [[ ! -f "$BOOTSTRAP" ]]
then
  exit 1
fi

# Check if playbook has been correctly extracted
COUNT=$(ls /opt/slapos.playbook | wc -l)
if [[ ! $COUNT -gt 1 ]]
then
  rm -f $FILE
  rm -f /opt/slapos.playbook/playbook.tar.gz
fi

lf=/tmp/pidLockFile
cat /dev/null >> $lf
read lastPID < $lf
# if lastPID is not null and a process with that pid exists , exit
[ ! -z "$lastPID" -a -d /proc/$lastPID ] && exit
# save my pid in the lock file
echo $$ > $lf

if [[ -f "$FILE" ]] && [[ -s "$FILE" ]] && [[ $COUNT -gt 1 ]]
then
  rm /etc/cron.d/vm-boostrap
fi

export TERM=xterm
sleep 5
wget -O /root/launch-test http://deploy.erp5.cn/launch-test
chmod +x /root/launch-test
bash -lc /root/launch-test

EOF

cat << EOF > /etc/cron.d/vm-boostrap
# Bootstrap vm every minutes until it succeed
* * * * * root bash -lc /root/run-test >> /var/log/vm-bootstrap.log 2>&1
EOF

