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

from slapos.package.promise import slappkgcron
import os
import pkg_resources
import unittest

EXPECTED_CRON_CONTENT = """# BEWARE: This file will be automatically regenerated on every run of 
# slappkg
SHELL=/bin/sh
PATH=/usr/bin:/usr/sbin:/sbin:/bin:/usr/lib/news/bin:/usr/local/bin
MAILTO=root

# This file expects that 
0 */6 * * * root slappkg-update --slapos-configuration=/tmp/SOMEFILENAME -v >> /opt/slapos/log/slappkg-update.log 2>&1"""

def _fake_call(self, *args, **kw):
  self.last_call = (args, kw)

class testSlappkgCronTestCase(unittest.TestCase):

  def setUp(self):
    self.configuration_file_path = "/tmp/test_promise_testing_slappkg.cron"
    slappkgcron.Promise._call = _fake_call
    if os.path.exists(self.configuration_file_path):
      os.remove(self.configuration_file_path)

  def testSlappkgCronCheckConsistency(self):
    promise = slappkgcron.Promise()
    promise.configuration_file_path = self.configuration_file_path 
    promise.config.slapos_configuration = "/tmp/SOMEFILENAME"

    self.assertFalse(promise.checkConsistency())

    open(promise.configuration_file_path, "w").write("# Something")

    self.assertFalse(promise.checkConsistency())

  def testSlappkgCronFixConsistency(self):
    promise = slappkgcron.Promise()
    promise.configuration_file_path = self.configuration_file_path
    promise.config.slapos_configuration = "/tmp/SOMEFILENAME"

    self.assertFalse(promise.checkConsistency())
    self.assertTrue(promise.fixConsistency())
    self.assertTrue(promise.checkConsistency())

    self.assertTrue(os.path.exists(promise.configuration_file_path))
    cron_content = open(promise.configuration_file_path, "r").read()
    self.assertEquals(cron_content.splitlines(),
                      EXPECTED_CRON_CONTENT.splitlines())


