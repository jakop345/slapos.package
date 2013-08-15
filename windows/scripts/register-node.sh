#! /bin/bash
#
#------------------------------------------------------------------------------
# Copyright (c) 2010, 2011, 2012 Vifib SARL and Contributors.
# All Rights Reserved.
#
# WARNING: This program as such is intended to be used by professional
# programmers who take the whole responsibility of assessing all potential
# consequences resulting from its eventual inadequacies and bugs
# End users who are looking for a ready-to-use solution with commercial
# guarantees and support are strongly advised to contract a Free Software
# Service Company
#
# This program is Free Software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 3
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
#------------------------------------------------------------------------------
#
# Run this script need the administrator priviledge.
#

# return GUID of physical netcard only
#
# Get the value of Characteristics of each interface,
# 
#    Characteristics & NCF_VIRTUAL == NCF_VIRTUAL
#    Characteristics & NCF_PHYSICAL == NCF_PHYSICAL
#    
function get_all_physical_netcard()
{
    local -r NCF_VIRTUAL=1
    local -r NCF_PHYSICAL=4
    local -r NCF_HIDDEN=8
    local -r NCF_HAS_UI=0x80
    local -r NCF_EXPECTED=$((NCF_PHYSICAL | NCF_HAS_UI))
    key='\HKLM\SYSTEM\CurrentControlSet\Control\Class\{4D36E972-E325-11CE-BFC1-08002bE10318}'
    
    for subkey in $(regtool -q list "$key") ; do
        local -i flags=$(regtool -q get "$key\\$subkey\Characteristics")
        if (( (flags & NCF_EXPECTED) == NCF_EXPECTED )) ; then
            regtool -q get "$key\\$subkey\NetCfgInstanceId" && return 0
        fi
    done
}

# get connection name by IF_GUID
function get_connection_name()
{
     key='\HKLM\SYSTEM\CurrentControlSet\Control\Network\{4D36E972-E325-11CE-BFC1-08002bE10318}'
     echo $(regtool -q get "$key\\$IF_GUID\Connection\Name")
}

#
# Tell by getmac, if GUID can be found, it's ok, else disabled or not connected
function get_interface_state()
{
  getmac /V /FO list | grep "${INTERFACENAME}"
  return $?
}

# test code
# slist=$(get_all_physical_netcard)
# echo physical netcards: $slist
# for s in $slist ; do
#     INTERFACE_NAME=$s
#     echo conn name is $(get_connection_name)
# done
# get_local_ip_version
# echo version is $local_ip_version
# exit 0

if [[ ! $(whoami) == Administrator ]] ; then
    echo "Error: only administrator can run this script."
    exit 1
fi

if [[ ! -d ~/.slapos ]] ; then
    echo "INFO: mkdir ~/.slapos"
    mkdir ~/.slapos
fi

if [[ ! ( -f ~/.slapos/certificate && -f ~/.slapos/key ) ]] ; then
    echo "Error: missing certificate and key in ~/.slapos  \

If you don't have an account in slapos.org, please login to https://www.slapos.org and signup. Otherwise check that both files are stored in ~/.slapos 
"
    exit 1
fi

if [[ ! -f ~/.slapos/slapos.cfg ]] ; then
    echo "INFO: generate configure file '~/.slapos/slapos.cfg'"
    echo "[slapos]
master_url = https://slap.vifib.com/

[slapconsole]
# Put here retrieved certificate from vifib.
# Beware: put certificate from YOUR account, not the one from your node.
# You (as identified person from vifib) will request an instance, not your node.
# Conclusion: node certificate != person certificate.
cert_file = ~/.slapos/certificate
key_file = ~/.slapos/key
# Below are softwares supported by Vifib
alias =
" > ~/.slapos/slapos.cfg
fi

# Remove startup item first.
RUNKEY='\HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'
SLAPOSNODEINIT=SlapOS-Node
regtool -q unset "$RUNKEY\\$SLAPOSNODEINIT"

nodename=$(hostname)
cd /opt/slapos
bin/slapos node register $nodename

# Check computer configure file: /etc/opt/slapos/slapos.cfg
nodecfg=/etc/opt/slapos/slapos.cfg
if [[ ! -f $nodecfg ]] ; then
    echo Error: something is wrong when registering the node. Cannot find the configuration file $nodecfg.
    exit 1
fi

# check ipv6
netsh interface ipv6 show interface > /dev/null || netsh interface ipv6 install

# get GUID of the first physical netcard
guidname=get_all_physical_netcard

if [[ "$guidname" == "" ]] ; then
    echo Error: no physical netcard found.
    exit 1
fi

# 
# Replace interface_name in the configure name
#
# generate /etc/slapos/slapos.cfg
sed -i  -e "s/^\\s*interface_name.*$/interface_name = ${IPINTERFACE}/g" \
        -e "s/^#\?\\s*ipv6_interface.*$/# ipv6_interface =/g" \
       $nodecfg

# 
# Add run item at windows startup
echo Set slapos init script as Windows startup item.
regtool -q set "$RUNKEY\\$SLAPOSNODEINIT" "\"$(cygpath -w /usr/bin/sh)\" --login -i /etc/slapos/scripts/init-slapos-node.sh"
(( $? )) && echo Failed to set init script as startup item.


