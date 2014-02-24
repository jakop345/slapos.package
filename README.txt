slapos.package
***************

SlapOS Package is a simple tool which aims on keep a packages updates on a Linux Distribution. The SlapOS Package can support multi distributions and use a simple signature file for take decision to upgrade or not the computer.

Basic Commands
===============

  # slappkg-update: Perform the update, if requested.

  # slappkg-discover: Prints the system signature, used to match with signature-list to decide which section to use.  

  # slappkg-upload-key: Uploads the signature configuration .

Basic Usage
============

  # slappkg-update --slapos-configuration update.cfg

Configuration Examples
========================

  * Example of update.cfg:

::
[slapupdate]
# Change this key for customise your upgrade.
upgrade_key = 'slapos-generic-upgrade-key'

[networkcache]
download-binary-cache-url = http://www.shacache.org/shacache
download-cache-url = https://www.shacache.org/shacache
download-binary-dir-url = http://www.shacache.org/shadir

signature-certificate-list =
  -----BEGIN CERTIFICATE-----
  MIIB8DCCAVmgAwIBAgIJAPFf61p8y809MA0GCSqGSIb3DQEBBQUAMBAxDjAMBgNV
  BAMMBUNPTVAtMCAXDTE0MDIxNzE2NDgxN1oYDzIxMTQwMTI0MTY0ODE3WjAQMQ4w
  DAYDVQQDDAVDT01QLTCBnzANBgkqhkiG9w0BAQEFAAOBjQAwgYkCgYEAsiqCyuv1
  HO9FmtwnMbEa1/u8Dn7T0k7hVKYXVQYof+59Ltbb3cA3nLjFSJDr/wQT6N89MccS
  PneRzkWqZKL06Kmj+N+XJfRyVaTz1qQtNzjdbYkO6RgQq+fvq2CO0+PSnL6NttLU
  /a9nQMcVm7wZ8kmY+AG5LbVo8lmxDD16Wq0CAwEAAaNQME4wHQYDVR0OBBYEFEVi
  YyWHF3W7/O4NaTjn4lElLpp7MB8GA1UdIwQYMBaAFEViYyWHF3W7/O4NaTjn4lEl
  Lpp7MAwGA1UdEwQFMAMBAf8wDQYJKoZIhvcNAQEFBQADgYEAgIPGoxhUa16AgjZx
  Jr1kUrs8Fg3ig8eRFQlBSLYfANIUxcQ2ScFAkmsvwXY3Md7uaSvMJsEl2jcjdmdi
  eSreNkx85j9GtMLY/2cv0kF4yAQNRtibtDkbg6fRNkmUopDosJNVf79l1GKX8JFL
  zZBOFdOaLYY/6dLRwiTUKHU6su8=
  -----END CERTIFICATE-----


  * Example of upgrade signature:

::
[debian-default]
repository-list = 
        main = http://ftp.fr.debian.org/debian/ wheezy main
        main-src = http://ftp.fr.debian.org/debian/ wheezy main
        update = http://ftp.fr.debian.org/debian/ wheezy-updates main
        update-src = http://ftp.fr.debian.org/debian/ wheezy-updates main
        slapos = http://download.opensuse.org/repositories/home:/VIFIBnexedi/Debian_7.0 ./
        re6stnet = http://git.erp5.org/dist/deb ./
filter-package-list = 
        ntp
        slapos.node
        re6stnet
signature-list = 
        debian+++jessie/sid+++

[opensuse-legacy]
repository-list = 
        suse = http://download.opensuse.org/distribution/12.1/repo/oss/
        slapos = http://download.opensuse.org/repositories/home:/VIFIBnexedi/openSUSE_12.1
        re6st = http://git.erp5.org/dist/rpm
filter-package-list = 
        ntp
        slapos.node
        re6stnet
signature-list = 
        opensuse+++12.1+++x86_64

[system]
reboot = 2011-10-10
upgrade = 2014-02-20

