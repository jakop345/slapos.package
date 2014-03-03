slapos.package
***************

SlapOS Package is a simple tool which aims on keep a packages updates on a Linux Distribution. The SlapOS Package can support multi distributions and use a simple signature file for take decision to upgrade or not the computer.

Basic Commands
===============

* slappkg-update: Perform the update, if requested.

* slappkg-discover: Prints the system signature, used to match with signature-list to decide which section to use.  

* slappkg-upload-key: Uploads the signature configuration.

* slappkg-conf: Creates initial update.cfg and cron entry.


Basic Usage
============

.. code:: bash

    # Generates initial configuration
    slappkg-conf --slapos-configuration=update.cfg 

    # Runs update
    slappkg-update --slapos-configuration=update.cfg

Upgrade Signature File
=======================

The signature file is composed by at least 2 sections:

System Section ([system]) where is defines reboot and upgrade expected dates. If 
server was upgraded before the dates present there, the upgrade will be trigger 
for packages (This only affects core promise).

Example:

.. code:: text

    [system]
    reboot = 2011-10-10
    upgrade = 2014-02-20

Distribution sections can have any other name choses by the user and it should 
contains the follow entries (always use new line for multiple values):

* repository-list: define a list of repository entries, defined by (name = value). 
                    Special minor notations explaned futher.

* filter-package-list: list of package names that are going to be keep installed and
                    updated.

* filter-promise-list: list of promises that are enabled for this distribution. The user
                    can decide which promises are going to be checked on every run. If this
                    section is not present, all promises available are going to be checked.

* signature-list: defines which systems the promises are applicable on. The signature for
                   every system can be found by slappkg-discover command. If None signature 
                   matches, the system will not be upgraded.
 
Example:

.. code:: text

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
    filter-promise-list =
      core
      hostname
    signature-list =
      debian+++jessie/sid+++

Configuration Examples
========================

* Example of update.cfg:

.. code:: text 

    [slapupdate]
    # Change this key for customise your upgrade.
    upgrade_key = 'slapos-generic-upgrade-key'

    [networkcache]
    download-binary-cache-url = http://www.shacache.org/shacache
    download-cache-url = https://www.shacache.org/shacache
    download-binary-dir-url = http://www.shacache.org/shadir

    # It is important to use only trustfull keys.
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

.. code:: text

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
    filter-promise-list = 
            core
            hostname
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
    
    
