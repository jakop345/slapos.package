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
import tempfile
import shutil
import os
import glob
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
    AptGet.source_list_path = "/tmp/test_distribution_sources.list"
    AptGet.source_list_d_path = "/tmp/test_distribution_sources.list.d"
    AptGet.trusted_gpg_d_path = "/tmp/test_distribution_trusted.gpg.d" 


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

  def testAptGetPurgeRepository(self):
    handler = AptGet()
    called = []
    def dummy_caller(*args, **kwargs):
      called.append("called")
  
    source_list = "/tmp/test_distribution_sources.list"
    source_list_d = "/tmp/test_distribution_sources.list.d"
 
    if not os.path.exists(source_list_d):
      os.mkdir(source_list_d)

    open("%s/couscous.list" % source_list_d, "w+").write("# test")
    handler.purgeRepository(dummy_caller)
    self.assertTrue(os.path.exists(source_list))
    self.assertEquals(open(source_list, "r").read(), 
                      "# Removed all")

    self.assertEquals(glob.glob("%s/*" % source_list_d), [])

  def testAptGetAddRepository(self):
    handler = AptGet()
    called = []
    def dummy_caller(*args, **kwargs):
      called.append("called")
  
    source_list_d = "/tmp/test_distribution_sources.list.d"
    if os.path.exists(source_list_d):
      shutil.rmtree(source_list_d)

    handler.addRepository(dummy_caller, "http://test main", "slapos")
    self.assertTrue(os.path.exists(source_list_d))
    self.assertEquals(open("%s/slapos.list" % source_list_d, "r").read(), 
                      "deb http://test main")


  def testAptGetAddKey(self):
    handler = AptGet()
    called = []
    def dummy_caller(*args, **kwargs):
      called.append("called")
  
    info, fake_gpg_path = tempfile.mkstemp()

    with open(fake_gpg_path, "w") as f:
      f.write("KEY")

    trusted_list_d = "/tmp/test_distribution_trusted.gpg.d" 
    if os.path.exists(trusted_list_d):
      shutil.rmtree(trusted_list_d)

    handler.addKey(dummy_caller, "file://%s" % fake_gpg_path, "slapos")
    self.assertTrue(os.path.exists(trusted_list_d))
    self.assertEquals(open("%s/slapos.gpg" % trusted_list_d, "r").read(), 
                      "KEY")

    
  def testAptGetUpdateRepository(self):
    handler = AptGet()
    called = []
    def dummy_caller(*args, **kwargs):
      called.append((args, kwargs))
  
    handler.updateRepository(dummy_caller)
    self.assertEquals(len(called), 1)
    command = called[0][0][0]
    extra = called[0][1]
    self.assertEquals(['apt-get', 'update'], command)
    self.assertEquals(extra, {'stdout': None})
    
  def testAptGetInstallSoftwareList(self):
    handler = AptGet()
    called = []
    def dummy_caller(*args, **kwargs):
      called.append((args, kwargs))
  
    handler.installSoftwareList(dummy_caller, ["slapos", "re6st"])
    self.assertEquals(len(called), 2)
    command = called[0][0][0]
    extra = called[0][1]
    self.assertEquals(['apt-get', 'update'], command)
    self.assertEquals(extra, {'stdout': None})
    
    command = called[1][0][0]
    extra = called[1][1]
    self.assertEquals(["apt-get", "install", "-y", "slapos", "re6st"], command)
    self.assertEquals(extra, {'stdout': None})

#  def isUpgradable(self, caller, name):
#    output, err = caller(["apt-get", "upgrade", "--dry-run"])
#    for line in output.splitlines(): 
#      if line.startswith("Inst %s" % name):
#        return True
#    return False
#      

  def testAptGetUpdateSoftware(self):
    handler = AptGet()
    called = []
    def dummy_caller(*args, **kwargs):
      called.append((args, kwargs))
  
    handler.updateSoftware(dummy_caller)
    self.assertEquals(len(called), 2)
    command = called[0][0][0]
    extra = called[0][1]
    self.assertEquals(['apt-get', 'update'], command)
    self.assertEquals(extra, {'stdout': None})
    
    command = called[1][0][0]
    extra = called[1][1]
    self.assertEquals(["apt-get", "upgrade"], command)
    self.assertEquals(extra, {'stdout': None})

  def testAptGetUpdateSystem(self):
    handler = AptGet()
    called = []
    def dummy_caller(*args, **kwargs):
      called.append((args, kwargs))
  
    handler.updateSystem(dummy_caller)
    self.assertEquals(len(called), 2)
    command = called[0][0][0]
    extra = called[0][1]
    self.assertEquals(['apt-get', 'update'], command)
    self.assertEquals(extra, {'stdout': None})
    
    command = called[1][0][0]
    extra = called[1][1]
    self.assertEquals(["apt-get", "dist-upgrade", "-y"], command)
    self.assertEquals(extra, {'stdout': None})

  def testZypperPurgeRepository_NoRepository(self):
    handler = Zypper()
    called = []
    def dummy_caller(*args, **kwargs):
      called.append((args, kwargs))
      return "", ""
  
    handler.purgeRepository(dummy_caller) 
   
    self.assertEquals(len(called), 1)
    command = called[0][0][0]
    extra = called[0][1]
    self.assertEquals(['zypper', 'lr'],
                      command)
    self.assertEquals(extra, {'stderr': -1, 'stdout': -1})

  def testZypperPurgeRepository_3Repository(self):
    handler = Zypper()
    called = []
    case = []
    repository_list_string = [
"""# | Alias  | Name   | Enabled | Refresh
--+--------+--------+---------+--------
1 | re6st  | re6st  | Yes     | Yes    
2 | slapos | slapos | Yes     | Yes    
3 | suse   | suse   | Yes     | Yes    
""",
"""# | Alias  | Name   | Enabled | Refresh
--+--------+--------+---------+--------
1 | slapos | slapos | Yes     | Yes    
2 | suse   | suse   | Yes     | Yes    
""",

"""# | Alias  | Name   | Enabled | Refresh
--+--------+--------+---------+--------
1 | suse   | suse   | Yes     | Yes    
""",
"""# | Alias  | Name   | Enabled | Refresh
--+--------+--------+---------+--------
"""]

    def dummy_caller(*args, **kwargs):
      called.append((args, kwargs))
      if args[0] == ['zypper', 'rr', '1']:
        case.append(1)
      return repository_list_string[len(case)], ""
  
    handler.purgeRepository(dummy_caller) 
   
    self.assertEquals(len(called), 7)
    command = called[0][0][0]
    extra = called[0][1]
    self.assertEquals(['zypper', 'lr'],
                      command)
    self.assertEquals(extra, {'stderr': -1, 'stdout': -1})

    command = called[1][0][0]
    extra = called[1][1]
    self.assertEquals(['zypper', 'rr', '1'],
                      command)
    self.assertEquals(extra, {'stdout': None})

    command = called[2][0][0]
    extra = called[2][1]
    self.assertEquals(['zypper', 'lr'],
                      command)
    self.assertEquals(extra, {'stderr': -1, 'stdout': -1})

    command = called[3][0][0]
    extra = called[3][1]
    self.assertEquals(['zypper', 'rr', '1'],
                      command)
    self.assertEquals(extra, {'stdout': None})

    command = called[4][0][0]
    extra = called[4][1]
    self.assertEquals(['zypper', 'lr'],
                      command)
    self.assertEquals(extra, {'stderr': -1, 'stdout': -1})

    command = called[5][0][0]
    extra = called[5][1]
    self.assertEquals(['zypper', 'rr', '1'],
                      command)
    self.assertEquals(extra, {'stdout': None})

    command = called[6][0][0]
    extra = called[6][1]
    self.assertEquals(['zypper', 'lr'],
                      command)
    self.assertEquals(extra, {'stderr': -1, 'stdout': -1})


  def purgeRepository(self, caller):
    listing, err = caller(['zypper', 'lr'], 
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    while listing.count('\n') > 2:
      output, err = caller(['zypper', 'rr', '1'], stdout=None)
      listing, err = caller(['zypper', 'lr'], 
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE)

  def testZypperAddRepository(self):
    handler = Zypper()
    called = []
    def dummy_caller(*args, **kwargs):
      called.append((args, kwargs))
  
    handler.addRepository(dummy_caller, "http://...", "slapos")
    handler.addRepository(dummy_caller, "http://.../2", "re6st-unsafe")
   
    self.assertEquals(len(called), 2)
    command = called[0][0][0]
    extra = called[0][1]
    self.assertEquals(['zypper', 'ar', '-fc', 'http://...', 'slapos'], 
                      command)
    self.assertEquals(extra, {'stdout': None})

    command = called[1][0][0]
    extra = called[1][1]
    self.assertEquals(['zypper', 'ar', '-fc', '--no-gpgcheck' , 
                       'http://.../2', 're6st-unsafe'], command)
    self.assertEquals(extra, {'stdout': None})
    
#  def addKey(self, caller, url, alias):
#    """ Add gpg or key """
#    raise NotImplementedError("Not implemented for this distribution")
#

  def testZypperUpdateRepository(self):
    handler = Zypper()
    called = []
    def dummy_caller(*args, **kwargs):
      called.append((args, kwargs))
  
    handler.updateRepository(dummy_caller)
    self.assertEquals(len(called), 1)
    command = called[0][0][0]
    extra = called[0][1]
    self.assertEquals(['zypper', '--gpg-auto-import-keys', 'in', '-Dly'], 
                      command)
    self.assertEquals(extra, {'stdout': None})
    
#  def isUpgradable(self, caller, name):
#    output, err = caller(['zypper', '--gpg-auto-import-keys', 'up', '-ly'], 
#                            stdout=subprocess.PIPE, stderr=subprocess.PIPE)
#    for line in output.splitlines():
#      if line.startswith("'%s' is already installed." % name):
#        return False
#    return True
#

  def testZypperInstallSoftwareList(self):
    handler = Zypper()
    called = []
    def dummy_caller(*args, **kwargs):
      called.append((args, kwargs))
  
    handler.installSoftwareList(dummy_caller, ["slapos", "re6st"])
    self.assertEquals(len(called), 2)
    command = called[0][0][0]
    extra = called[0][1]
    self.assertEquals(['zypper', '--gpg-auto-import-keys', 'in', '-Dly'], 
                      command)
    self.assertEquals(extra, {'stdout': None})

    command = called[1][0][0]
    extra = called[1][1]
    self.assertEquals(command, 
      ['zypper', '--gpg-auto-import-keys', 'in', '-ly', 'slapos', 're6st'])
    self.assertEquals(extra, {'stdout': None})

  def testZypperUpdateSoftware(self):
    handler = Zypper()
    called = []
    def dummy_caller(*args, **kwargs):
      called.append((args, kwargs))
  
    handler.updateSoftware(dummy_caller)
    self.assertEquals(len(called), 1)
    command = called[0][0][0]
    extra = called[0][1]
    self.assertEquals(['zypper', '--gpg-auto-import-keys', 'up', '-ly'], 
                      command)
    self.assertEquals(extra, {'stdout': None})

  def testZypperUpdateSystem(self):
    handler = Zypper()
    called = []
    def dummy_caller(*args, **kwargs):
      called.append((args, kwargs))
  
    handler.updateSystem(dummy_caller)
    self.assertEquals(len(called), 1)
    command = called[0][0][0]
    extra = called[0][1]
    self.assertEquals(['zypper', '--gpg-auto-import-keys', 'dup', '-ly'], 
                      command)
    self.assertEquals(extra, {'stdout': None})

