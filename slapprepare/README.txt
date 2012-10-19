slapprepare
***********

Slapprepare is the script responsible to prepare a openSUSE computer to run slapos as a dedicated machine.

Process
-------------------------------------------
1. Will parse option and set basic parameters
2. Add slapos repositories with zypper
3. Install latest version of slapos but will deactivate slapos-node service
    (Wait till everything is ready)
4. If option --update or -u wasn't choosen slapprepare will consider
   it need to prepare computer like a newborn one
   -It is a first run and ask a few question a user:
     * "Automatically register new computer to Vifib?" (Default is yes)
        is yes choosen two more question will follow:
        "Define a unique name for this computer:"
        	      Unique name to register computer on Vifib Master
        "Number of SlapOS partitions for this computer? Default is 20 :"
        	      Partition amount for this computer
     * "Is this a virtual Machine?" (Default is False)
         Is it a virtual machine? Default is false
     * If not a virtual machine:
       "Do you want to use SlapOS with a second disk?" (Default is True)
        If True selected the script slapos_firstboot will be run searching
        for second a second disk.
     * "Do you want to use vpn to provide ipv6?" (Default is Yes)
        If False selected will remove openvpn-needed file in config directory
     * "Do you want to force the use lxc on this computer?" (Default is No)
        If Yes choosen will run "# touch /etc/opt/slapos/SlapContainer-needed"
     * "Do you want a remote ssh access?" (Default is Yes)
        If yes is choosen, will later ask for a web address
	 to download user' public ssh key and put it in root authorized_keys
   -If automatically register to vifib was choosen
     it will run slapos node register which prepare slapos configuration
   -Display computer's reference ("Your Computer is : COMP-1234")
   -If remote ssh access was choosen will ask for public key address
     and download it.
   -Will prepare computer:
   	 * Setting hostname
	 * Adding the hostname as a valid address
	 * Creating safe sshd_config
	 * Creating default bridge config
	 * If remote ssh: Writing ssh key
	 * Adding slapos_firstboot in case of MultiDisk usage
   - If multi-disk usage it will run slapos_firstboot and reinstall slapos
5. It will install boot script that are not included in package
   - Boot script in "/usr/sbin/slapos-boot-dedicated"
     and its associated service in:
          "/etc/systemd/system/slapos-boot-dedicated.service"
   - clientipv4 (openvpn conf)
   - Remove script form older versions of slapprepare
6. Configure NTP daemon
7. "#systemctl enable slapos-boot-dedicated.service"
   "#systemctl start slapos-boot-dedicated.service"
   Will activate an start slapos-boot-dedicated

About slapos-boot-dedicated
-------------------------------------------
It is in slapprepare/script/slapos

Process
+++++++
1. Deactivate slapos-node.service (daemon from package) to prepare quietly
2. Check ipv4-ipv6 and start openvpn if needed or asked
3. Reset root password
4. Check if slapos is installed (if not reinstall it)
5. Create PKI repository
6. If slapos.cfg is not in /etc/opt/slapos/ it correct path in package
    script and cron file
7. Set dedicated cron file "/etc/cron.d/slapos"
   - If SlapContainer-needed file in configuration directory  will add a line
      to use it
8. Set various parameters to improve running performance of slapos



How to update you old Suse Image (Suse 12.1 or sooner)
------------------------------------------------------
Run this whole command as root:

# wget http://www.nexedi.org/static/packages/source/slapprepare/slapprepare.tar.gz; zypper remove -y slapos.node; rm -f /etc/opt/slapos/slapos.node*.rpm; tar -xzf slapprepare.tar.gz; cd slapprepare; python setup.py install; cd .. ; rm -r slapprepare* ; slapprepare -u ;


Check your config
-------------------------------------------
Check your config file and your cron file
+++++++++++++++++++++++++++++++++++++++++
Run:
# slapos-test
This script will check your config file for missing section or parameters

You can use the slapos.cfg.example config file as reference for slapos.cfg.
http://git.erp5.org/gitweb/slapos.core.git/blob_plain/HEAD:/slapos.cfg.example


Check dedicated cron file
+++++++++++++++++++++++++
# less /etc/cron.d/slapos

It should contain a call to slapupdate

Check your configuration directory
++++++++++++++++++++++++++++++++++
# ls /etc/opt/slapos/

It should only contain your slapos configuration files and *-needed files


Configure your machine:
-------------------------------------------
LXC
++++
If you want to run lxc on you machine run these command:

# touch /etc/opt/slapos/SlapContainer-needed ; systemctl restart slapos-boot-dedicated.service

openvpn
+++++++
Openvpn by vifib for ipv6 is forced by default in the package.
- If you want to deactivate it run
# rm /etc/opt/slapos/openvpn-needed



