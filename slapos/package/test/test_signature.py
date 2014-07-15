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

from slapos.package import update, signature
from slapos.libnetworkcache import NetworkcacheClient
from optparse import Values
import slapos.signature
import time
import difflib
import tempfile
import unittest
import os

SIGNATURE = "\n-----BEGIN CERTIFICATE-----\nMIIB8DCCAVmgAwIBAgIJAPFf61p8y809MA0GCSqGSIb3DQEBBQUAMBAxDjAMBgNV\nBAMMBUNPTVAtMCAXDTE0MDIxNzE2NDgxN1oYDzIxMTQwMTI0MTY0ODE3WjAQMQ4w\nDAYDVQQDDAVDT01QLTCBnzANBgkqhkiG9w0BAQEFAAOBjQAwgYkCgYEAsiqCyuv1\nHO9FmtwnMbEa1/u8Dn7T0k7hVKYXVQYof+59Ltbb3cA3nLjFSJDr/wQT6N89MccS\nPneRzkWqZKL06Kmj+N+XJfRyVaTz1qQtNzjdbYkO6RgQq+fvq2CO0+PSnL6NttLU\n/a9nQMcVm7wZ8kmY+AG5LbVo8lmxDD16Wq0CAwEAAaNQME4wHQYDVR0OBBYEFEVi\nYyWHF3W7/O4NaTjn4lElLpp7MB8GA1UdIwQYMBaAFEViYyWHF3W7/O4NaTjn4lEl\nLpp7MAwGA1UdEwQFMAMBAf8wDQYJKoZIhvcNAQEFBQADgYEAgIPGoxhUa16AgjZx\nJr1kUrs8Fg3ig8eRFQlBSLYfANIUxcQ2ScFAkmsvwXY3Md7uaSvMJsEl2jcjdmdi\neSreNkx85j9GtMLY/2cv0kF4yAQNRtibtDkbg6fRNkmUopDosJNVf79l1GKX8JFL\nzZBOFdOaLYY/6dLRwiTUKHU6su8=\n-----END CERTIFICATE-----"

BASE_UPDATE_CFG_DATA = """

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

"""
UPDATE_CFG_DATA = """
[slapupdate]
upgrade_key = slapos-upgrade-testing-key-with-config-file-invalid

""" + BASE_UPDATE_CFG_DATA

UPDATE_UPLOAD_CFG_DATA = """
[slapupdate]
upgrade_key = slapos-upgrade-testing-key-with-config-file

""" + BASE_UPDATE_CFG_DATA

VALID_UPDATE_CFG_DATA = """
[slapupdate]
upgrade_key = 'slapos-upgrade-testing-key-with-config-file-valid' 

""" + BASE_UPDATE_CFG_DATA


UPDATE_CFG_WITH_UPLOAD_DATA = UPDATE_CFG_DATA + """
signature_private_key_file = /etc/opt/slapos/signature.key
signature_certificate_file = /etc/opt/slapos/signature.cert
upload-cache-url = https://www.shacache.org/shacache
shacache-cert-file = /etc/opt/slapos/shacache.crt
shacache-key-file = /etc/opt/slapos/shacache.key
upload-dir-url = https://www.shacache.org/shadir
shadir-cert-file = /etc/opt/slapos/shacache.crt
shadir-key-file = /etc/opt/slapos/shacache.key
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



def _fake_upload(self, *args, **kwargs):
  return True

class NetworkCacheTestCase(unittest.TestCase):

  def setUp(self):
    self.original_networkcache_upload = NetworkcacheClient.upload
    NetworkcacheClient.upload = _fake_upload


    self.config_dict = {
      "slapos_configuration": self._createConfigurationFile(),
      "srv_file": "/tmp/test_base_promise_slapupdate",
      "dry_run": False,
      "verbose": False 
    }
   
  def tearDown(self):
    NetworkcacheClient.upload = self.original_networkcache_upload

  def _createConfigurationFile(self):
    with open("/tmp/test_signature_000000_configuration.cfg", "w") as configuration_file:
      configuration_file.write(VALID_UPDATE_CFG_DATA)
    return "/tmp/test_signature_000000_configuration.cfg"

  def test_basic_configuration(self):
    info, self.configuration_file_path = tempfile.mkstemp()
    open(self.configuration_file_path, 'w').write(UPDATE_CFG_DATA)
    shacache = signature.NetworkCache(self.configuration_file_path)
    self.assertEqual(shacache.download_binary_cache_url,
                     "http://www.shacache.org/shacache")
    self.assertEqual(shacache.download_cache_url,
                     "https://www.shacache.org/shacache")
    self.assertEqual(shacache.download_binary_dir_url,
                     "http://www.shacache.org/shadir")

    self.assertEqual(shacache.signature_certificate_list,
                     SIGNATURE)            

    self.assertEqual(shacache.directory_key,
                     'slapos-upgrade-testing-key-with-config-file-invalid')
    # Check keys that don't exist
    # Not mandatory
    self.assertEqual(shacache.dir_url , None)
    self.assertEqual(shacache.cache_url , None)
    self.assertEqual(shacache.signature_private_key_file , None)
    self.assertEqual(shacache.shacache_cert_file , None)
    self.assertEqual(shacache.shacache_key_file , None)
    self.assertEqual(shacache.shadir_cert_file , None)
    self.assertEqual(shacache.shadir_key_file , None)


  def test_basic_configuration_with_upload(self):
    info, self.configuration_file_path = tempfile.mkstemp()
    open(self.configuration_file_path, 'w').write(UPDATE_CFG_WITH_UPLOAD_DATA)
    shacache = signature.NetworkCache(self.configuration_file_path)
    self.assertEqual(shacache.download_binary_cache_url,
                     "http://www.shacache.org/shacache")
    self.assertEqual(shacache.download_cache_url,
                     "https://www.shacache.org/shacache")
    self.assertEqual(shacache.download_binary_dir_url,
                     "http://www.shacache.org/shadir")

    self.assertEqual(shacache.signature_certificate_list,
                     SIGNATURE)            

    self.assertEqual(shacache.directory_key,
                     'slapos-upgrade-testing-key-with-config-file-invalid')
    # Check keys that don't exist
    # Not mandatory
    self.assertEqual(shacache.dir_url , 'https://www.shacache.org/shadir')
    self.assertEqual(shacache.cache_url , 'https://www.shacache.org/shacache')
    self.assertEqual(shacache.shacache_cert_file , '/etc/opt/slapos/shacache.crt')
    self.assertEqual(shacache.shacache_key_file , '/etc/opt/slapos/shacache.key')
    self.assertEqual(shacache.shadir_cert_file , '/etc/opt/slapos/shacache.crt')
    self.assertEqual(shacache.shadir_key_file , '/etc/opt/slapos/shacache.key')

    self.assertEqual(shacache.signature_private_key_file ,'/etc/opt/slapos/signature.key')

  def test_configuration_file_dont_exist(self):
    self.assertRaises(ValueError, signature.NetworkCache, 
                          "/abc/123")

  def test_download_not_existing_signature_from_cache(self):
    info, path = tempfile.mkstemp()
    info, self.configuration_file_path = tempfile.mkstemp()
    open(self.configuration_file_path, 'w').write(UPDATE_CFG_DATA)
    shacache = signature.NetworkCache(self.configuration_file_path)
    
    self.assertEquals(False, 
      shacache.download(path=path, required_key_list=['timestamp'],
                        strategy=signature.strategy)) 

    self.assertEquals("", open(path, 'r').read())

  def test_download_existing_from_cache(self):
    info, path = tempfile.mkstemp()
    info, self.configuration_file_path = tempfile.mkstemp()
    open(self.configuration_file_path, 'w').write(VALID_UPDATE_CFG_DATA)
    shacache = signature.NetworkCache(self.configuration_file_path)
    
    shacache.download(path=path, 
                        required_key_list=['timestamp'],
                        strategy=signature.strategy)
   
    self.maxDiff = None

    self.assertEquals(UPGRADE_KEY.splitlines(), 
                      open(path, 'r').read().splitlines())

  def test_upload_to_cache(self):
    
    info, path = tempfile.mkstemp()
    info, _fake_signature_path = tempfile.mkstemp()
    info, self.configuration_file_path = tempfile.mkstemp()

    signature_certificate_file = "/tmp/signature_certificate_file_demo_test"
    if os.path.exists(signature_certificate_file):
      os.remove(signature_certificate_file)

    signature_private_key_file = "/tmp/signature_private_key_file_demo_test"
    if os.path.exists(signature_private_key_file):
      os.remove(signature_private_key_file)

    slapos.signature.generateCertificate(signature_certificate_file,
                                         signature_private_key_file, 
                                         "COMP-123A")

    configuration_content = UPDATE_UPLOAD_CFG_DATA + """
signature_private_key_file = %(signature_private_key_file)s 
signature_certificate_file = %(signature_certificate_file)s
upload-cache-url = https://www.shacache.org/shacache
shacache-cert-file = %(tempfile)s
shacache-key-file = %(tempfile)s
upload-dir-url = https://www.shacache.org/shadir
shadir-cert-file = %(tempfile)s
shadir-key-file = %(tempfile)s
""" % {"tempfile": _fake_signature_path, 
       "signature_certificate_file": signature_certificate_file,
       "signature_private_key_file": signature_private_key_file }

    open(self.configuration_file_path, 'w').write(
      configuration_content)

    open(_fake_signature_path, "w").write("# XXX ...")

    shacache = signature.NetworkCache(self.configuration_file_path)
    metadata_dict = {'timestamp': time.time(),}
    shacache.upload(path=path, metadata_dict=metadata_dict)

  def test_signature_strategy(self):

    entry_list = [
      {'timestamp': 123824.0}, 
      {'timestamp': 12345.0}, 
      {'timestamp': 13345.0}, 
      {'timestamp': 12344.0}, 
      {'timestamp': 12045.0}, 
      ]

    self.assertEquals(
        signature.strategy(entry_list), 
            {'timestamp': 123824.0})

  def testLoadSignature(self):
    sig = signature.Signature(Values(self.config_dict))

    self.assertNotEquals(getattr(sig, "current_state", "COUSOUS!!!"), 
                                 "COUSCOUS!!!")

    sig.load()

    self.assertNotEquals(sig.current_state, None)
    self.assertEquals(sig.reboot.strftime("%Y-%m-%d"), "2011-10-10" )  
    self.assertEquals(sig.upgrade.strftime("%Y-%m-%d"), "2014-06-04" )  
    self.assertEquals(sig.last_reboot, None )  
    self.assertEquals(sig.last_upgrade, None )  


  def testLoadSignatureWithLast(self):
    modified_config_dict = self.config_dict.copy()
    info, slapupdate_path = tempfile.mkstemp()
    with open(slapupdate_path, "w") as slapupdate_file:
      slapupdate_file.write("""
[system]
reboot = 2010-10-10
upgrade = 2010-06-04
""")
    modified_config_dict["srv_file"] = slapupdate_path
    sig = signature.Signature(Values(modified_config_dict))

    self.assertNotEquals(getattr(sig, "current_state", "COUSOUS!!!"), 
                                 "COUSCOUS!!!")

    sig.load()

    self.assertNotEquals(sig.current_state, None)
    self.assertEquals(sig.reboot.strftime("%Y-%m-%d"), "2011-10-10" )  
    self.assertEquals(sig.upgrade.strftime("%Y-%m-%d"), "2014-06-04" )  
    self.assertEquals(sig.last_reboot.strftime("%Y-%m-%d"), "2010-10-10" )  
    self.assertEquals(sig.last_upgrade.strftime("%Y-%m-%d"), "2010-06-04" )  


  def testSignatureUpdate(self):
    modified_config_dict = self.config_dict.copy()
    info, slapupdate_path = tempfile.mkstemp()
    with open(slapupdate_path, "w") as slapupdate_file:
      slapupdate_file.write("""
[system]
reboot = 2010-10-10
upgrade = 2010-06-04
""")
    modified_config_dict["srv_file"] = slapupdate_path
    sig = signature.Signature(Values(modified_config_dict))


    sig.load()

    self.assertNotEquals(sig.current_state, None)
    self.assertEquals(sig.reboot.strftime("%Y-%m-%d"), "2011-10-10" )  
    self.assertEquals(sig.upgrade.strftime("%Y-%m-%d"), "2014-06-04" )  
    self.assertEquals(sig.last_reboot.strftime("%Y-%m-%d"), "2010-10-10" )  
    self.assertEquals(sig.last_upgrade.strftime("%Y-%m-%d"), "2010-06-04" )  

    sig.update(reboot="2014-07-01")

    self.assertEquals(open(slapupdate_path, "r").read().strip(), """[system]
reboot = 2014-07-01
upgrade = 2010-06-04""")

    sig.update(upgrade="2014-07-03")

    self.assertEquals(open(slapupdate_path, "r").read().strip(), """[system]
reboot = 2014-07-01
upgrade = 2014-07-03""")

    sig.update(reboot="2014-08-10", upgrade="2014-08-11")

    self.assertEquals(open(slapupdate_path, "r").read().strip(), """[system]
reboot = 2014-08-10
upgrade = 2014-08-11""")


