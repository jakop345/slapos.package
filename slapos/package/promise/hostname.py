#!/usr/bin/python
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
import os

class Promise(BasePromise):

  configuration_file_path = '/etc/HOSTNAME' 

  def _getComputerId(self, **kw):
    if kw.get("computer_id"):
      return kw["computer_id"]
   
    return self.getSlapOSConfigurationDict("slapos").get("computer_id")

  def checkConsistency(self, fixit=0, **kw):
    is_ok = False
    computer_id = self._getComputerId(**kw)

    if computer_id is None:
      self.log("Unable to detect computer_id from configuration.")
      return is_ok 

    if os.path.exists(self.configuration_file_path):
       is_ok = computer_id in open(self.configuration_file_path, 'r').read()

    if not is_ok and fixit:
      return self.fixConsistency(**kw)

    return is_ok

  def fixConsistency(self, **kw):
    """Configures hostname daemon"""
    computer_id = self._getComputerId(**kw)
    if computer_id is None:
      return self.checkConsistency(fixit=0, computer_id=computer_id, **kw)

    self.log("Setting hostname in : %s" % self.configuration_file_path)
    open(self.configuration_file_path, 'w').write("%s\n" % computer_id)
    self._call(['hostname', '-F', self.configuration_file_path])
    return self.checkConsistency(fixit=0, **kw)

