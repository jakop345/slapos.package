mkdir -p /root/bootstrap

echo 0 > /root/bootstrap/retry-amount
echo 10 > /root/bootstrap/bootstrap-max-retry

touch /root/bootstrap/start-bootstrap

# Put cron task to bootstrap vm
cat << EOF > /etc/cron.d/vm-boostrap
# Bootstrap vm every minutes until it succeed
* * * * * root bash -lc /root/bootstrap/vm-bootstrap >> /var/log/vm-bootstrap.log 2>&1
EOF

# VM bootstrap script
cat << EOF > /root/bootstrap/vm-bootstrap
#!/bin/bash

cd /root/bootstrap
if [[ ! -f "start-bootstrap" ]]
then
  exit 1
fi
MAXRETRY=\`cat bootstrap-max-retry\`
RETRY=\`cat retry-amount\`

lf=/tmp/pidLockFile
cat /dev/null >> \$lf
read lastPID < \$lf
# if lastPID is not null and a process with that pid exists , exit
[ ! -z "\$lastPID" -a -d /proc/\$lastPID ] && exit
# save my pid in the lock file
echo \$\$ > \$lf

sleep 3
wget -O bootstrap-script -q http://10.0.2.100/vm-bootstrap
if [[ ! -s "bootstrap-script" ]]
then
  echo "exit 1" > bootstrap-script
fi
export TERM=xterm
bash bootstrap-script

RESULT=\$?
test_result=\$((\$MAXRETRY - \$RETRY - 1))
if [[ \$test_result -le 0 ]]
then
  rm -f /etc/cron.d/vm-boostrap
  echo "Maximun bootstrap retry amount reached..."
fi
echo \$((\$RETRY + 1)) > retry-amount

if [[ \$RESULT != 0 ]]
then
  echo "ERROR: bootstrap script exited with return code \$RESULT."
  exit \$RESULT
fi

rm -f /etc/cron.d/vm-boostrap
exit 0

EOF

chmod +x /root/bootstrap/vm-bootstrap

