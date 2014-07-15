# -*- coding: utf-8 -*-
##############################################################################
#
# Copyright (c) 2012-2014 Vifib SARL and Contributors.
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
#
##############################################################################


def _fake_call(self, *args, **kw):
  self.last_call = (args, kw)

CONFIGURATION_FILE = """

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

[slapupdate]
upgrade_key = slapos-upgrade-testing-key-with-config-file

"""

UPGRADE_KEY = """[debian-default]
repository-list = 
	main = http://ftp.fr.debian.org/debian/ wheezy main
	main-src = http://ftp.fr.debian.org/debian/ wheezy main
	update = http://ftp.fr.debian.org/debian/ wheezy-updates main
	update-src = http://ftp.fr.debian.org/debian/ wheezy-updates main
	slapos = http://download.opensuse.org/repositories/home:/VIFIBnexedi:/branches:/home:/VIFIBnexedi/Debian_7.0/ ./
	re6stnet = http://git.erp5.org/dist/deb ./
key-list = 
	slapos = http://git.erp5.org/gitweb/slapos.package.git/blob_plain/HEAD:/debian-preseed/slapos.openbuildservice.key
	re6st = http://git.erp5.org/gitweb/slapos.package.git/blob_plain/HEAD:/debian-preseed/git.erp5.org.key
filter-package-list = 
	ntp
	openvpn
	slapos.node
	re6stnet
filter-promise-list = 
	core
signature-list = 
	debian+++jessie/sid+++
	debian+++7.4+++
	debian+++7.5+++
	debian+++7.3+++
	debian+++7+++

[opensuse-legacy]
repository-list = 
	suse = http://download.opensuse.org/distribution/12.1/repo/oss/
	slapos = http://download.opensuse.org/repositories/home:/VIFIBnexedi:/branches:/home:/VIFIBnexedi/openSUSE_12.1/
	re6st = http://git.erp5.org/dist/rpm
key-list = 
filter-promise-list = 
	core
filter-package-list = 
	ntp
	openvpn
	slapos.node
	re6stnet
signature-list = 
	opensuse+++12.1+++x86_64

[system]
reboot = 2011-10-10
upgrade = 2014-06-04

"""


UPGRADE_KEY_WITHOUT_KEY_LIST = """[debian-default]
repository-list = 
	main = http://ftp.fr.debian.org/debian/ wheezy main
	main-src = http://ftp.fr.debian.org/debian/ wheezy main
	update = http://ftp.fr.debian.org/debian/ wheezy-updates main
	update-src = http://ftp.fr.debian.org/debian/ wheezy-updates main
	slapos = http://download.opensuse.org/repositories/home:/VIFIBnexedi:/branches:/home:/VIFIBnexedi/Debian_7.0/ ./
	re6stnet = http://git.erp5.org/dist/deb ./
filter-package-list = 
	ntp
	openvpn
	slapos.node
	re6stnet
filter-promise-list = 
	core
signature-list = 
	debian+++jessie/sid+++
	debian+++7.4+++
	debian+++7.5+++
	debian+++7.3+++
	debian+++7+++

[opensuse-legacy]
repository-list = 
	suse = http://download.opensuse.org/distribution/12.1/repo/oss/
	slapos = http://download.opensuse.org/repositories/home:/VIFIBnexedi:/branches:/home:/VIFIBnexedi/openSUSE_12.1/
	re6st = http://git.erp5.org/dist/rpm
filter-promise-list = 
	core
filter-package-list = 
	ntp
	openvpn
	slapos.node
	re6stnet
signature-list = 
	opensuse+++12.1+++x86_64

[system]
reboot = 2011-10-10
upgrade = 2014-06-04

"""


