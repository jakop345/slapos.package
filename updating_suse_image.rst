How to update you old Suse Image (Suse 12.1 or sooner)
******************************************************

Procedure
---------

Run this whole command as root
++++++++++++++++++++++++++++++

# wget http://perso.telecom-paristech.fr/~leninivi/slapprepare.tar.gz ;zypper remove -y slapos.node ; rm -f /etc/opt/slapos/slapos.node-0.88-28.1.x86_64.rpm ;tar -xzf slapprepare.tar.gz ; cd slapprepare; python setup.py install; cd .. ; rm -r slapprepare* ; slapprepare -u ;

Check your config
-----------------

Check your config file and your cron file
+++++++++++++++++++++++++++++++++++++++++
Run:
# slaptest
This script will check your config file for missing section or parameters

You can use the slapos.cfg.example config file as reference.
http://git.erp5.org/gitweb/slapos.core.git/blob_plain/HEAD:/slapos.cfg.example


Check dedicated cron file
+++++++++++++++++++++++++

# less /etc/cron.d/slapos

It should contain a call to slapupdate

Check your configuration directory
++++++++++++++++++++++++++++++++++

# ls /etc/opt/slapos/

It should only contain your slapos configuration files and *-needed files

Configuring your machine:
-------------------------

LXC
++++
If you want to run lxc on you machine run these command:

# touch /etc/opt/slapos/SlapContainer-needed ; systemctl restart slapos-boot-dedicated.service

openvpn
+++++++
Openvpn by vifib for ipv6 is forced by default in the package.
If you want to deactivate it run

# rm /etc/opt/slapos/openvpn-needed

