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

from slapos.package.distribution import PackageManager, AptGet, Zypper, \
                                        UnsupportedOSException 
import os
import unittest

def _fake_call(self, *args, **kw):
  self.last_call = args

def _fake_debian_distribution(*args, **kw):
  return ('debian', '7.4', '')

def _fake_opensuse_distribution(*args, **kw):
  return ('OpenSuse ', '12.1', '')

class DummyDistributionHandler:
  called = []
  def purgeRepository(self, caller):
    self.called.append("purgeRepository")

  def addRepository(self, caller, url, alias):
    self.called.append("addRepository")

  def addKey(self, caller, url, alias):
    self.called.append("addKey")

  def updateRepository(self, caller):
    self.called.append("updateRepository")

  def isUpgradable(self, caller, name):
    self.called.append("isUpgradeble")

  def installSoftwareList(self, caller, name_list):
    self.called.append("installSoftwareList")

  def updateSoftware(self, caller):
    self.called.append("updateSoftware")

  def updateSystem(self, caller):
    self.called.append("updateSystem")

class testPackageManager(unittest.TestCase):

  def setUp(self):
    PackageManager._call = _fake_call

  def testGetDistributionHandler(self):
    package_manager = PackageManager()
    def OpenSuseCase(): 
      return "OpenSuse"

    package_manager.getDistributionName = OpenSuseCase
    self.assertTrue(
      isinstance(package_manager._getDistributionHandler(), Zypper))

    def DebianCase(): 
      return "Debian"

    package_manager.getDistributionName = DebianCase
    self.assertTrue(
      isinstance(package_manager._getDistributionHandler(), AptGet))

    def RedHatCase(): 
      return "Red Hat"

    package_manager.getDistributionName = RedHatCase
    self.assertRaises(UnsupportedOSException, 
                      package_manager._getDistributionHandler)

  def testGetDistributionName(self):
    package_manager = PackageManager()
    package_manager._getLinuxDistribution = _fake_opensuse_distribution
    self.assertEquals(package_manager.getDistributionName(), "OpenSuse ")
   
    package_manager._getLinuxDistribution = _fake_debian_distribution
    self.assertEquals(package_manager.getDistributionName(), "debian")


  def testGetVersion(self):
    package_manager = PackageManager()
    package_manager._getLinuxDistribution = _fake_opensuse_distribution
    self.assertEquals(package_manager.getVersion(), "12.1")
   
    package_manager._getLinuxDistribution = _fake_debian_distribution
    self.assertEquals(package_manager.getVersion(), "7.4")

  def testOSSignature(self):
    
    package_manager = PackageManager()
    package_manager._getLinuxDistribution = _fake_opensuse_distribution
    self.assertEquals(package_manager.getOSSignature(), "opensuse+++12.1+++")
   
    package_manager._getLinuxDistribution = _fake_debian_distribution
    self.assertEquals(package_manager.getOSSignature(), "debian+++7.4+++")

  def _getPatchedPackageManagerForApiTest(self):
    package_manager = PackageManager()
    dummy_handler = DummyDistributionHandler()

    def DummyCase():
      dummy_handler.called = []
      return dummy_handler

    package_manager._getDistributionHandler = DummyCase

    self.assertEquals(package_manager._getDistributionHandler(), dummy_handler)
    self.assertEquals(dummy_handler.called, [])
    return package_manager, dummy_handler

  def testPurgeRepositoryAPI(self):
    package_manager, handler = self._getPatchedPackageManagerForApiTest()
    package_manager._purgeRepository()
    self.assertEquals(handler.called, ["purgeRepository"])

  def testAddRepositoryAPI(self):
    package_manager, handler = self._getPatchedPackageManagerForApiTest()
    package_manager._addRepository("http://...", "slapos")
    self.assertEquals(handler.called, ["addRepository"])

  def testAddKeyAPI(self):
    package_manager, handler = self._getPatchedPackageManagerForApiTest()
    package_manager._addKey("http://...", "slapos")
    self.assertEquals(handler.called, ["addKey"])


  def testUpdateRepositoryAPI(self):
    package_manager, handler = self._getPatchedPackageManagerForApiTest()
    package_manager._updateRepository()
    self.assertEquals(handler.called, ["updateRepository"])

  def testInstalledSoftwareListAPI(self):
    package_manager, handler = self._getPatchedPackageManagerForApiTest()
    package_manager._installSoftwareList(["slapos", "re6st"])
    self.assertEquals(handler.called, ["installSoftwareList"])

  def testUpdateSoftwareAPI(self):
    package_manager, handler = self._getPatchedPackageManagerForApiTest()
    package_manager._updateSoftware()
    self.assertEquals(handler.called, ["updateSoftware"])

  def testUpdateSystemAPI(self):
    package_manager, handler = self._getPatchedPackageManagerForApiTest()
    package_manager._updateSystem()
    self.assertEquals(handler.called, ["updateSystem"])

