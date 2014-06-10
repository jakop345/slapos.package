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
    self.assertRaises(UnsupportedOSException, package_manager._getDistributionHandler)

    
