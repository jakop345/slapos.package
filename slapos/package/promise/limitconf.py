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
import pkg_resources


class Promise(BasePromise):

  configuration_file_path = '/etc/security/limits.conf' 

  def _getLimitConfTemplate(self):
    return pkg_resources.resource_stream(__name__,
                         'template/limits.conf.in').read()

  def checkConsistency(self, fixit=0, **kw):
    is_ok = False

    if os.path.exists(self.configuration_file_path):
       expected_limit = self._getLimitConfTemplate()
       with open(self.configuration_file_path, 'r') as limit_conf:
         is_ok = expected_limit == limit_conf.read()

    if not is_ok and fixit:
      return self.fixConsistency(**kw)

    return is_ok

  def fixConsistency(self, **kw):
    """Configures hostname daemon"""

    self.log("Update limits : %s" % self.configuration_file_path)
    if os.path.exists(self.configuration_file_path):
      shutil.copy(self.configuration_file_path, 
        "%s.%s" % (self.configuration_file_path, time.time()))
    
    with open(self.configuration_file_path, 'w') as limit_conf:
      limit_conf.write(self._getLimitConfTemplate())

    return self.checkConsistency(fixit=0, **kw)

