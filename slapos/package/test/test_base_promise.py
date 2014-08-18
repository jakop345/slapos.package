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

from slapos.package.base_promise import BasePromise
from slapos.package.test.base import CONFIGURATION_FILE, UPGRADE_KEY, _fake_call 
import os
from slapos.package.signature import NetworkCache
from optparse import Values
import unittest

FAKE_CALL_COUNTER = 0 

def _fake_signature_download(self, path, *args, **kwargs):
  global FAKE_CALL_COUNTER
  FAKE_CALL_COUNTER += 1

  with open(path, 'w') as upgrade_signature:
    upgrade_signature.write(UPGRADE_KEY)

  return True

class testBasePromiseCase(unittest.TestCase):

  def setUp(self):
    self.original_basepromise_call = BasePromise._call
    BasePromise._call = _fake_call
    self.original_network_cache_download = NetworkCache.download
    NetworkCache.download = _fake_signature_download
    global FAKE_CALL_COUNTER
    FAKE_CALL_COUNTER = 0

    self.config_dict = {
      "slapos_configuration": self._createConfigurationFile(),
      "srv_file": "/tmp/test_base_promise_slapupdate",
      "dry_run": False,
      "verbose": False 
    }

  def tearDown(self):
    BasePromise._call = self.original_basepromise_call 
    NetworkCache.download = self.original_network_cache_download
   

  def _createConfigurationFile(self):
    with open("/tmp/test_base_promise_configuration.cfg", "w") as configuration_file:
      configuration_file.write(CONFIGURATION_FILE)
    return "/tmp/test_base_promise_configuration.cfg"


  def testIsSystemd(self):
    promise = BasePromise()
    systemctl_path = "/tmp/_testBasePromiseCase_systemctl_test"
    promise.systemctl_path_list = ["/tmp/_testBasePromiseCase_systemctl_test"]
    if os.path.exists(systemctl_path):
      os.remove(systemctl_path)

    self.assertFalse(promise._isSystemd())

    open(systemctl_path, "w").write("echo test")
    self.assertTrue(promise._isSystemd())

  def testSystemctl(self):
    promise = BasePromise()
    def _fake_true_isSystemd():
      return True

    promise._isSystemd = _fake_true_isSystemd

    promise._service("service_name", "service_action")

    self.assertEqual(promise.last_call, 
             ((['systemctl', 'service_action', 'service_name'],),
                {'dry_run': False, 'stderr': None, 'stdout': None}))

  def testService(self):
    promise = BasePromise()
    def _fake_false_isSystemd():
      return False

    promise._isSystemd = _fake_false_isSystemd

    promise._service("service_name", "service_action")

    self.assertEqual(promise.last_call, 
                     ((['service', 'service_name', 'service_action'],),
                        {'dry_run': False, 'stderr': None, 'stdout': None}))

  def testGetSignature(self):
    global FAKE_CALL_COUNTER
    promise = BasePromise(Values(self.config_dict))
    self.assertEquals(FAKE_CALL_COUNTER, 0)
    signature = promise.getSignature()

    self.assertNotEquals(signature, None)

    self.assertEquals(FAKE_CALL_COUNTER, 1)
    # Make sure is already loaded. 
    self.assertNotEquals(signature.current_state, None)    
    self.assertEquals(signature.reboot.strftime("%Y-%m-%d"), "2011-10-10" )  

    # Make sure it do not download things again.
    signature = promise.getSignature()
    self.assertEquals(FAKE_CALL_COUNTER, 1)

  def testGetSlapOSConfiguration(self):
    promise = BasePromise(Values(self.config_dict))
    self.assertEquals(promise.getSlapOSConfigurationDict("slapupdate"),
      {'upgrade_key': 'slapos-upgrade-testing-key-with-config-file'})

  def testGetPromiseSectionDict(self):
    
    promise = BasePromise(Values(self.config_dict))
    def fake_debian_getOSSignature():
      return "debian+++7.4+++"

    def fake_opensuse_getOSSignature():
      return "opensuse+++12.1+++x86_64"

    def fake_unsupported_getOSSignature():
      return "readhat+++1+++"

    promise.getOSSignature = fake_unsupported_getOSSignature
    self.assertEquals(promise.getPromiseSectionDict(), None)

    promise.getOSSignature = fake_opensuse_getOSSignature
    opensuse_dict = {'filter-promise-list': ['core'], 
                     'filter-package-list': ['ntp', 'openvpn', 'slapos.node', 're6stnet'], 
                      'key-list': [], 
                      'repository-list': [
                        'suse = http://download.opensuse.org/distribution/12.1/repo/oss/', 
                        'slapos = http://download.opensuse.org/repositories/home:/VIFIBnexedi:/branches:/home:/VIFIBnexedi/openSUSE_12.1/', 
                        're6st = http://git.erp5.org/dist/rpm'], 
                     'signature-list': ['opensuse+++12.1+++x86_64']}
    self.assertEquals(promise.getPromiseSectionDict(), opensuse_dict)

    promise.getOSSignature = fake_debian_getOSSignature
    debian_dict = {'filter-promise-list': ['core'], 
                   'filter-package-list': ['ntp', 'openvpn', 'slapos.node', 're6stnet'], 
                   'key-list': [
                     'slapos = http://git.erp5.org/gitweb/slapos.package.git/blob_plain/HEAD:/debian-preseed/slapos.openbuildservice.key', 
                     're6st = http://git.erp5.org/gitweb/slapos.package.git/blob_plain/HEAD:/debian-preseed/git.erp5.org.key'], 
                   'repository-list': [
                     'main = http://ftp.fr.debian.org/debian/ wheezy main', 
                     'main-src = http://ftp.fr.debian.org/debian/ wheezy main', 
                     'update = http://ftp.fr.debian.org/debian/ wheezy-updates main', 
                     'update-src = http://ftp.fr.debian.org/debian/ wheezy-updates main', 
                     'slapos = http://download.opensuse.org/repositories/home:/VIFIBnexedi:/branches:/home:/VIFIBnexedi/Debian_7.0/ ./', 
                     're6stnet = http://git.erp5.org/dist/deb ./'], 
                   'signature-list': ['debian+++jessie/sid+++', 'debian+++7.4+++', 'debian+++7.5+++', 
                                      'debian+++7.3+++', 'debian+++7+++']}
    self.assertEquals(promise.getPromiseSectionDict(), debian_dict)


  def testIsAplicable(self):
   
    from slapos.package.promise import core, limitconf 
    def fake_debian_getOSSignature():
      return "debian+++7.4+++"


    promise = core.Promise(Values(self.config_dict))
    promise.getOSSignature = fake_debian_getOSSignature
    self.assertEquals(promise.isApplicable(), True)


    promise = limitconf.Promise(Values(self.config_dict))
    promise.getOSSignature = fake_debian_getOSSignature
    self.assertEquals(promise.isApplicable(), False)
 
