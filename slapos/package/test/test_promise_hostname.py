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

from slapos.package.promise import hostname
import os
import unittest

def _fake_call(self, *args, **kw):
  self.last_call = (args, kw)

class testPromiseHostnameCase(unittest.TestCase):

  def setUp(self):
    hostname.Promise._call = _fake_call

  def testHostnameCheckConsistency(self):
    promise = hostname.Promise()
    promise.configuration_file_path = "/tmp/hostname_for_test"

    self.assertFalse(promise.checkConsistency(computer_id="TESTING"))

  def testHostnameFixConsistency(self):
    hostname.Promise._call = _fake_call
    promise = hostname.Promise()
    promise.configuration_file_path = "/tmp/hostname_for_test_fix"

    if os.path.exists(promise.configuration_file_path):
      os.remove(promise.configuration_file_path)

    self.assertFalse(promise.checkConsistency(computer_id="TESTING"))
    self.assertTrue(promise.fixConsistency(computer_id="TESTING"))
    self.assertEqual(promise.last_call, 
                     ((['hostname', '-F', '/tmp/hostname_for_test_fix'],), {})
                    )
