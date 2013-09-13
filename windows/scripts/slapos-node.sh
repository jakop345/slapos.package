#! /bin/bash
source $(/usr/bin/dirname $0)/slapos-include.sh

# -----------------------------------------------------------
# Start script
# -----------------------------------------------------------
csih_inform "Start slapos-node script ..."
echo ""

# -----------------------------------------------------------
# Local variables
# -----------------------------------------------------------
declare computer_guid

# -----------------------------------------------------------
# Check all the configure files
# -----------------------------------------------------------
check_network_configure
check_node_configure
check_client_configure
check_cron_configure
check_re6stnet_configure

# -----------------------------------------------------------
# Check cygwin services used by slapos
# -----------------------------------------------------------
check_cygwin_service ${cygserver_service_name}
check_cygwin_service ${syslog_service_name}
check_cygwin_service ${cron_service_name}
check_openvpn_needed && check_cygwin_service ${re6stnet_service_name}

# -----------------------------------------------------------
# Get computer reference
# -----------------------------------------------------------
computer_guid=$(grep "CN=COMP" ${node_certificate_file} | \
    sed -e "s/^.*, CN=//g" | sed -e "s%/emailAddress.*\$%%g")
[[ "${computer_guid}" == COMP-+([0-9]) ]] ||
csih_error_multi "${computer_guid} is invalid computer guid." \
    "It should like 'COMP-XXXX', edit ${node_certificate_file}" \
    "to fix it."
csih_inform "Got computer reference id: ${computer_guid}"

# -----------------------------------------------------------
# Format slapos node
# -----------------------------------------------------------
csih_inform "Formatting SlapOS Node ..."
/opt/slapos/bin/slapos node format -cv --now ||
csih_error "Run slapos node format failed. "

# -----------------------------------------------------------
# Run slapos software
# -----------------------------------------------------------
/opt/slapos/bin/slapos node software --verbose

# -----------------------------------------------------------
# Run slapos instance
# -----------------------------------------------------------
csih_inform "Creating instance ..."
/opt/slapos/bin/slapos node instance --verbose

# -----------------------------------------------------------
# Run slapos report
# -----------------------------------------------------------
csih_inform "Sending report ..."
/opt/slapos/bin/slapos node report --verbose

# -----------------------------------------------------------
# End script
# -----------------------------------------------------------
echo ""
csih_inform "Run slapos-node script successfully."
echo ""

read -n 1 -t 60 -p "Press any key to exit..."
exit 0
