
yum install -y wget vim

cat << EOF > /etc/NetworkManager/NetworkManager.conf
[main]
plugins=ifcfg-rh,keyfile

[keyfile]
unmanaged-devices=interface-name:eth1

EOF
