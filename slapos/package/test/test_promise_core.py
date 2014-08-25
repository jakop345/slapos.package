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

import datetime
from slapos.package.promise import core
from slapos.package.test.base import CONFIGURATION_FILE, UPGRADE_KEY, \
                                     _fake_call, UPGRADE_KEY_WITHOUT_KEY_LIST
from slapos.package.signature import NetworkCache
from optparse import Values

import os
import unittest


def _fake_update(self, repository_list=[], package_list=[], key_list=[]):
  self._fake_update_call = (repository_list, package_list, key_list)
      
def fake_debian_getOSSignature():
  return "debian+++7.4+++"

def _log_message_list(self, message):
  if getattr(self, "_message_list", None) is None:
    self._message_list = []
  self._message_list.append(message)

class TestCoreCase(unittest.TestCase):

  def setUp(self):
    core.Promise._call = _fake_call
    core.Promise.log = _log_message_list

    self.original_promise_update = core.Promise.update
    core.Promise.update = _fake_update

    self.original_network_cache_download = NetworkCache.download    

    # Patch Download
    def _fake_signature_download(self, path, *args, **kwargs):
      with open(path, 'w') as upgrade_signature:
        upgrade_signature.write(UPGRADE_KEY)
      return True

    NetworkCache.download = _fake_signature_download


    self.config_dict = {
      "slapos_configuration": self._createConfigurationFile(),
      "srv_file": "/tmp/test_base_promise_slapupdate",
      "dry_run": False,
      "verbose": False 
    }
   
  def tearDown(self):
    NetworkCache.download = self.original_network_cache_download
    core.Promise.update = self.original_promise_update

  def _createConfigurationFile(self):
    with open("/tmp/test_base_promise_configuration.cfg", "w") as configuration_file:
      configuration_file.write(CONFIGURATION_FILE)
    return "/tmp/test_base_promise_configuration.cfg"

  def testCheckConsistencyFirstTime(self):

    modified_config_dict = self.config_dict.copy()
    modified_config_dict["srv_file"] = "/tmp/test_promise_core_which_do_not_exist"

    promise = core.Promise(Values(modified_config_dict))
    self.assertEquals(promise.checkConsistency(), False)
    self.assertEquals(promise._message_list[-2], "Last reboot : None")
    self.assertEquals(promise._message_list[-1], "Last upgrade : None")

  def testCheckConsistencyAlreadyUpgraded(self):

    modified_config_dict = self.config_dict.copy()

    slapupdate_path = "/tmp/test_promise_core_testCheckConsistencyAlreadyUpgraded"
    with open(slapupdate_path, 'w') as slapupdate:
      slapupdate.write("""[system]
upgrade = 2014-11-11
reboot = 2015-11-11
""")

    modified_config_dict["srv_file"] = slapupdate_path

    promise = core.Promise(Values(modified_config_dict))
    self.assertEquals(promise.checkConsistency(), True)
    self.assertEquals(promise._message_list[-2], "Your system is up to date")
    self.assertEquals(promise._message_list[-1], 'No need to reboot.')

  def testCheckConsistencyRebootIsRequired(self):

    modified_config_dict = self.config_dict.copy()

    slapupdate_path = "/tmp/test_promise_core_testCheckConsistencyRebootIsRequired"
    with open(slapupdate_path, 'w') as slapupdate:
      slapupdate.write("""[system]
upgrade = 2000-11-11
reboot = 2009-11-11
""")

    modified_config_dict["srv_file"] = slapupdate_path

    promise = core.Promise(Values(modified_config_dict))
    self.assertEquals(promise.checkConsistency(), False)
    self.assertEquals(promise._message_list[-1], "Rebooting is required.")

  def testCheckConsistencyUpgradeIsRequired(self):

    modified_config_dict = self.config_dict.copy()

    slapupdate_path = "/tmp/testCheckConsistencyUpgradeIsRequired"
    with open(slapupdate_path, 'w') as slapupdate:
      slapupdate.write("""[system]
upgrade = 2000-11-11
reboot = 2100-11-11
""")

    modified_config_dict["srv_file"] = slapupdate_path

    promise = core.Promise(Values(modified_config_dict))
    self.assertEquals(promise.checkConsistency(), False)
    self.assertEquals(promise._message_list[-1], 'No need to reboot.')
    self.assertEquals(promise._message_list[-2], "Upgrade is required.")

  def testCheckConsistencyUpgradeInFuture(self):

    # Patch Download
    def _fake_signature_download(self, path, *args, **kwargs):
      copy_of_upgrade_key = UPGRADE_KEY
      with open(path, 'w') as upgrade_signature:
        modified_upgrade_key = copy_of_upgrade_key.replace(
                                              "upgrade = 2014-06-04", 
                                              "upgrade = 2100-01-01") 
        upgrade_signature.write(modified_upgrade_key)
      return True

    NetworkCache.download = _fake_signature_download

    modified_config_dict = self.config_dict.copy()
    modified_config_dict["srv_file"] = "/tmp/test_promise_core_which_do_not_exist"

    promise = core.Promise(Values(modified_config_dict))
    self.assertEquals(promise.checkConsistency(), True)
    self.assertEquals(promise._message_list[-1], 'Upgrade will happens on 2100-01-01')

  def testFixConsistency(self):
    
    modified_config_dict = self.config_dict.copy()
    
    def _fake_update(self, repository_list=[], package_list=[], key_list=[]):
      self._fake_update_call = (repository_list, package_list, key_list)
      
    slapupdate_path = "/tmp/testFixConsistencyUpgrade"
    with open(slapupdate_path, 'w') as slapupdate:
      slapupdate.write("""[system]
upgrade = 2000-11-11
reboot = 2100-11-11
""")

    modified_config_dict["srv_file"] = slapupdate_path

    promise = core.Promise(Values(modified_config_dict))
    self.assertEquals(promise.checkConsistency(fixit=1), True)
    expected_message_list = [
      'Expected Reboot early them 2011-10-10', 
      'Expected Upgrade early them 2014-06-04', 
      'Last reboot : 2100-11-11', 
      'Last upgrade : 2000-11-11', 
      'Upgrade is required.', 
      'Retrying after fixConsistency....\n\n', 
      'Expected Reboot early them 2011-10-10', 
      'Expected Upgrade early them 2014-06-04', 
      'Last reboot : 2100-11-11', 
      'Last upgrade : %s' % datetime.datetime.today().strftime("%Y-%m-%d"),
      'Your system is up to date', 
      'No need to reboot.', 
      'No need to reboot.']
    self.assertEquals(promise._message_list, expected_message_list)

    repository_list = [
      ('main', 'http://ftp.fr.debian.org/debian/ wheezy main'), 
      ('main-src', 'http://ftp.fr.debian.org/debian/ wheezy main'),  
      ('update', 'http://ftp.fr.debian.org/debian/ wheezy-updates main'), 
      ('update-src', 'http://ftp.fr.debian.org/debian/ wheezy-updates main'), 
      ('slapos', 'http://download.opensuse.org/repositories/home:/VIFIBnexedi:/branches:/home:/VIFIBnexedi/Debian_7.0/ ./'), 
      ('re6stnet', 'http://git.erp5.org/dist/deb ./')]
    filter_package_list = ['ntp', 'openvpn', 'slapos.node', 're6stnet'] 
    key_list = [
       ('slapos', 'http://git.erp5.org/gitweb/slapos.package.git/blob_plain/HEAD:/debian-preseed/slapos.openbuildservice.key'), 
       ('re6st', 'http://git.erp5.org/gitweb/slapos.package.git/blob_plain/HEAD:/debian-preseed/git.erp5.org.key')] 

    self.assertEquals(promise._fake_update_call[0], repository_list)

    self.assertEquals(promise._fake_update_call[1], filter_package_list)

    self.assertEquals(promise._fake_update_call[2], key_list) 


  def testFixConsistency_without_key_list(self):
    
    modified_config_dict = self.config_dict.copy()

    # Patch Download
    def _fake_signature_download(self, path, *args, **kwargs):
      with open(path, 'w') as upgrade_signature:
        modified_upgrade_key = UPGRADE_KEY_WITHOUT_KEY_LIST.replace(
              "upgrade = 2014-06-04", 
              "upgrade = %s" % datetime.datetime.today().strftime("%Y-%m-%d")) 
        upgrade_signature.write(modified_upgrade_key)
      return True

    NetworkCache.download = _fake_signature_download
    
    def _fake_update(self, repository_list=[], package_list=[], key_list=[]):
      self._fake_update_call = (repository_list, package_list, key_list)
      
    slapupdate_path = "/tmp/testFixConsistencyUpgrade"
    with open(slapupdate_path, 'w') as slapupdate:
      slapupdate.write("""[system]
upgrade = 1999-11-11
reboot = 2100-11-11
""")

    modified_config_dict["srv_file"] = slapupdate_path

    promise = core.Promise(Values(modified_config_dict))
    self.assertEquals(promise.checkConsistency(fixit=1), True)
    self.maxDiff = None

    _today = datetime.datetime.today().strftime("%Y-%m-%d")
    expected_message_list = [
      'Expected Reboot early them 2011-10-10', 
      'Expected Upgrade early them %s' % _today, 
      'Last reboot : 2100-11-11', 
      'Last upgrade : 1999-11-11', 
      'Upgrade is required.',
      'Retrying after fixConsistency....\n\n',
      'Expected Reboot early them 2011-10-10',
      'Expected Upgrade early them %s' % _today,
      'Last reboot : 2100-11-11',
      'Last upgrade : %s' % _today,
      'Your system is up to date',
      'No need to reboot.',
      'No need to reboot.']

    self.assertEquals(promise._message_list, expected_message_list)

    repository_list = [
      ('main', 'http://ftp.fr.debian.org/debian/ wheezy main'), 
      ('main-src', 'http://ftp.fr.debian.org/debian/ wheezy main'),  
      ('update', 'http://ftp.fr.debian.org/debian/ wheezy-updates main'), 
      ('update-src', 'http://ftp.fr.debian.org/debian/ wheezy-updates main'), 
      ('slapos', 'http://download.opensuse.org/repositories/home:/VIFIBnexedi:/branches:/home:/VIFIBnexedi/Debian_7.0/ ./'), 
      ('re6stnet', 'http://git.erp5.org/dist/deb ./')]
    filter_package_list = ['ntp', 'openvpn', 'slapos.node', 're6stnet'] 
    key_list = [] 

    self.assertEquals(promise._fake_update_call[0], repository_list)

    self.assertEquals(promise._fake_update_call[1], filter_package_list)

    self.assertEquals(promise._fake_update_call[2], key_list) 

