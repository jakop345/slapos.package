#! /bin/bash
source $(/usr/bin/dirname $0)/slapos-include.sh
echo 
echo "Start slapos-node script ..."
echo

# -----------------------------------------------------------
# Check all the configure files
# -----------------------------------------------------------
check_network_configure || exit 1
check_node_configure || exit 1
check_client_configure || exit 1
check_cron_configure
check_re6stnet_configure

# -----------------------------------------------------------
# Check cygwin services used by slapos
# -----------------------------------------------------------
check_cygwin_service cygserver || exit 1
check_cygwin_service syslog-ng || exit 1
check_cygwin_service sshd
check_cygwin_service cron
check_re6stnet_needed && check_cygwin_service re6stnet

# -----------------------------------------------------------
# Create instance of slap web runner
# -----------------------------------------------------------
create_slapos_webrunner_instance || exit 1

# -----------------------------------------------------------
# Format slapos node
# -----------------------------------------------------------
echo "Formating SlapOS Node ..."
/opt/slapos/bin/slapos node format -cv --now || exit 1

# -----------------------------------------------------------
# Release software
# -----------------------------------------------------------
echo "Releasing software ..."
/opt/slapos/bin/slapos node software --verbose

# -----------------------------------------------------------
# Instance software
# -----------------------------------------------------------
echo "Creating instance ..."
/opt/slapos/bin/slapos node instance --verbose

# -----------------------------------------------------------
# Send report
# -----------------------------------------------------------
echo "Sending report ..."
/opt/slapos/bin/slapos node report --verbose

echo 
echo "Run slapos-node script successfully."
echo 
read -n 1 -t 60 -p "Press any key to exit..."
exit 0
