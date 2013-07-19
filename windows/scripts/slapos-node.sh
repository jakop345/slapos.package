#! /bin/bash
source $(/usr/bin/dirname $0)/slapos-include.sh
csih_inform "Start slapos-node script ..."

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
check_cygwin_service cygserver
check_cygwin_service syslog-ng
check_cygwin_service sshd
check_cygwin_service cron
check_re6stnet_needed && check_cygwin_service re6stnet

# -----------------------------------------------------------
# Get computer reference and re6stnet network
# -----------------------------------------------------------
computer_guid=$(grep "CN=COMP" ${node_certificate_file} | \
    sed -e "s/^.*, CN=//g" | sed -e "s%/emailAddress.*\$%%g")
[[ "${computer_guid}" == COMP-+([0-9]) ]] ||
csih_error_multi "${computer_guid} is invalid computer guid." \
    "It should like 'COMP-XXXX', edit ${node_certificate_file}" \
    "to fix it."
csih_inform "Got computer reference id: ${computer_guid}"

# -----------------------------------------------------------
# Get re6stnet network
# -----------------------------------------------------------
if [[ -r ${re6stnet_configure_file} ]] ; then
    _addr6=$(grep "Your subnet" ${re6stnet_configure_file} | \
        sed -e "s/^.*subnet: //g" -e "s/\/80 (CN.*\$/1/g")
    if [[ -n "${_addr6}" ]] ; then
        csih_inform "Re6stnet address in this computer: ${_addr6}"
        netsh interface ipv6 show addr ${slapos_ifname} level=normal | \
            grep -q " ${_addr6}\$" || \
            netsh interface ipv6 add addr ${slapos_ifname} ${_addr6}
    fi
fi

# -----------------------------------------------------------
# Format slapos node
# -----------------------------------------------------------
csih_inform "Formating SlapOS Node ..."
/opt/slapos/bin/slapos node format -cv --now ||
csih_error "Run slapos node format failed. "

# -----------------------------------------------------------
# Request an instance of slapos webrunner
# -----------------------------------------------------------
csih_inform "Supply slaposwebrunner in the computer ${computer_guid}"
/opt/slapos/bin/slapos supply slaposwebrunner ${computer_guid}
_title="SlapOS-WebRunner-In-${computer_guid}"
csih_inform "Request slaposwebrunner instance as ${_title}"
/opt/slapos/bin/slapos request ${client_configure_file} \
    ${_title} slaposwebrunner --node computer_guid=${computer_guid} 

# -----------------------------------------------------------
# Enter loop to release software, create instance, report
# -----------------------------------------------------------
_patch_file=/etc/slapos/patches/slapos-cookbook-inotifyx.patch
while true ; do
    csih_inform "Releasing software ..."
    /opt/slapos/bin/slapos node software --verbose || continue

    if [[ -r ${_patch_file} ]] ; then
        for _x in $(find /opt/slapgrid/ -name slapos.cookbook-*.egg) ; do
            patch -d ${_x} -f --dry-run -p1 < ${_patch_file} > /dev/null && 
            csih_inform "Apply patch ${_patch_file} on ${_x}" &&
            patch -d ${_x} -p1 < ${_patch_file}
        done
    fi
    
    csih_inform "Creating instance ..."
    /opt/slapos/bin/slapos node instance --verbose || continue

    csih_inform "Sending report ..."
    /opt/slapos/bin/slapos node report --verbose || continue

    get_slapos_webrunner_instance ${computer_guid} ${_title} && break
done

echo ""
csih_inform "Run slapos-node script successfully."
echo ""

read -n 1 -t 60 -p "Press any key to exit..."
exit 0
