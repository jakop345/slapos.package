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

import datetime
import logging
from optparse import OptionParser, Option
import sys
from slapos.package.base_promise import BasePromise


class Promise(BasePromise):

  def fixConsistency(self, upgrade=0, reboot=0, boot=0, **kw):
    signature = self.getSignature()
    today = datetime.date.today().isoformat()
    if upgrade:
      upgrade_goal = self.getPromiseSectionDict()
      if upgrade_goal is None:
        raise ValueError("None of the sections are compatible for upgrade!")
        
      repository_tuple_list = []
      for repository in upgrade_goal['repository-list']:
        alias, url = repository.split("=")
        repository_tuple_list.append((alias.strip(), url.strip()))

      key_tuple_list = []
      for key in upgrade_goal['key-list']:
        alias, url = key.split("=")
        key_tuple_list.append((alias.strip(), url.strip()))

      self.update(repository_tuple_list, 
                  upgrade_goal['filter-package-list'], 
                  key_tuple_list)

    if upgrade and boot:
      signature.update(reboot=today, upgrade=today)
    if upgrade:
      signature.update(upgrade=today)
    elif reboot:
      signature.update(reboot=today)
    else:
      raise ValueError(
        "You need upgrade and/or reboot when invoke fixConsistency!")

  def checkConsistency(self, fixit=0, **kw):
  
    # Get configuration
    signature = self.getSignature()
  
    self.log("Expected Reboot early them %s" % signature.reboot)
    self.log("Expected Upgrade early them %s" % signature.upgrade)
    self.log("Last reboot : %s" % signature.last_reboot)
    self.log("Last upgrade : %s" % signature.last_upgrade)

    if signature.upgrade > datetime.date.today():
      self.log("Upgrade will happens on %s" % signature.upgrade)
      return
 
    # Check if run for first time
    if signature.last_reboot is None:
      if fixit:
        # Purge repositories list and add new ones
        self.fixConsistency(upgrade=1, boot=1)
    else:
      if signature.last_upgrade < signature.upgrade:
        # Purge repositories list and add new ones
        if fixit:
          self.fixConsistency(upgrade=1)
      else:
        self.log("Your system is up to date")
  
      if signature.last_reboot < signature.reboot:
        if not self.config.dry_run:
          self.fixConsistency(reboot=1)
        else:
          self.log("Dry run: Rebooting required.")

