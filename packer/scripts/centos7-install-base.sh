
yum provides ifconfig

yum install -y net-tools wget vim

systemctl stop firewalld
systemctl disable firewalld

cat << EOF > /etc/NetworkManager/NetworkManager.conf
[main]
plugins=ifcfg-rh,keyfile

[keyfile]
unmanaged-devices=interface-name:eth1

EOF
