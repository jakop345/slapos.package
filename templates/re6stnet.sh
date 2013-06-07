SLAPOS_CFG_PATH=/etc/opt/slapos/slapos.cfg

function re6st_conf_generation
{
    # Generate re6st configuration
    read -p "Please enter the registry you wish to use for re6st[http://re6stnet.nexedi.com]: " REGISTRY
    REGISTRY=${REGISTRY:-http://re6stnet.nexedi.com}
    read -p "Please enter your email for token generation: " EMAIL
    re6st-conf --registry $REGISTRY --email $EMAIL -r emailAddress $EMAIL -d /etc/re6stnet
	  echo "File /etc/re6stnet/re6stnet.conf generated"
    echo "You now need to reboot your server manually for the changes to take\
effect"
}

function remove_VPN_conf
{
    # Remove VPN configuration
    if [ -e /etc/openvpn/vifib.conf ]; then
        rm /etc/openvpn/vifib.conf
        rm -Rf /etc/openvpn/vifib-keys
	      echo "Removed vifib OpenVPN configuration files"
    fi
    
    if [ -e /etc/opt/slapos/openvpn-needed ]; then
        rm /etc/opt/slapos/openvpn-needed
	      echo "Removed /etc/opt/slapos/openvpn-needed"
    fi
}

function modify_interfaces_in_SlapOS_conf
{
    # Modify slapos.cfg to use lo
    cp $SLAPOS_CFG_PATH $SLAPOS_CFG_PATH.old
    echo "Copied old slapos.cfg to $SLAPOS_CFG_PATH.old"
    
    sed 's/\(interface_name =\).*/\1 lo/g' $SLAPOS_CFG_PATH.old > $SLAPOS_CFG_PATH.tmp
    sed 's/.*ipv6_interface =.*//g' $SLAPOS_CFG_PATH.tmp > $SLAPOS_CFG_PATH
    rm $SLAPOS_CFG_PATH.tmp
}

#XXX Vivien: fugly logic, feel free to modify it if you can do better
#            or if install/upgrade procedure was simplified
if [ -e $SLAPOS_CFG_PATH ]; then
    # In case of an upgrade test for native ipv6 inside slapos.cfg
    if grep -qe "ipv6_interface" $SLAPOS_CFG_PATH && ! grep -qe "#ipv6_interface" $SLAPOS_CFG_PATH; then
        # If using vifib VPN        
        remove_VPN_conf
       
        modify_interfaces_in_SlapOS_conf
       
        re6st_conf_generation

    elif [ ! -e /etc/re6stnet/re6stnet.conf ]; then
        if grep -qe "interface_name = lo" $SLAPOS_CFG_PATH; then
            # New node with new configuration case
            re6st_conf_generation
        
        else
            # Manual configuration by user before upgrade
            echo "You seem to have no separate interface for ipv6, please proceed \
with the configuration of re6st and SlapOS Node by yourself."
    fi
fi

