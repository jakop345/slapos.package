About auto update system
************************

Auto-update system is composed of two script:
- slapudate.py in charge of updating/upgrading computer
- upload-update.py in charge of uploading update information


slapupdate
----------
slapudate is called by a cron job every day at midnight.

It will connect to shacache to obtain last update information available.
This file give authorized reporitories, date of needed reboot and upgrade
and requested openSUSE version.

If update date is newer than last requested update:
1. We remove all repositories
2. We add authorized repositories
3. We check openSUSE version
- If requested version is higher than current version we do a dist-upgrade
  and reboot
- Else we run upgrade

If reboot date is newer than last requested one on we reboot.


upload-update
-------------

This script will use a slapos-upgrade information file
(in /etc/slapos-cache/slapos-upgrade by default),
modify it according to option, ask confirmation and upload it to shacache.

- Note: You will need your slapos.cfg for shacache upload ready in /etc/slapos-cache/

options
+++++++
  --upgrade-file=UPGRADE_FILE
                        File use as reference to upgrade.
  -u, --upgrade         If selected will update tomorrow.
  -r, --reboot          If selected will reboot tomorrow.
  -n, --dry-run         Simulate the execution steps
  -h, --help            show this help message and exit

slapos-upgrade information file
+++++++++++++++++++++++++++++++
[repositories]
suse = http://download.opensuse.org/distribution/12.1/repo/oss/
slapos = http://download.opensuse.org/repositories/home:/VIFIBnexedi/openSUSE_12.1

[system]
reboot = 2012-09-05
upgrade = 2012-09-05
opensuse_version = 12.1

Example
+++++++

- We want computers to update (at midnight)
python upload-update.py -u

- We want computers to update and reboot (at midnght)
python upload-update.py -u -r

