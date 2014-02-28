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
from signature import Signature
from promise import promise_list

class Parser(OptionParser):
  """
  Parse all arguments.
  """
  def __init__(self, usage=None, version=None):
    """
    Initialize all options possibles.
    """
    OptionParser.__init__(self, usage=usage, version=version,
                      option_list=[
        Option("--slapos-configuration",
               default='/etc/opt/slapos/slapos.cfg',
               help="Path to slapos configuration file"),
        Option("--srv-file",
               default='/srv/slapupdate',
               help="Server status file."),
        Option("-v", "--verbose",
               default=False,
               action="store_true",
               help="Verbose output."),
        Option("-n", "--dry-run",
               help="Simulate the execution steps",
               default=False,
               action="store_true"),
        ])

  def check_args(self):
    """
    Check arguments
    """
    (options, args) = self.parse_args()
    return options

def do_update():
  """Update computer and slapos"""
  usage = "usage: %s [options] " % sys.argv[0]
  config_dict = Parser(usage=usage).check_args()

  for promise_klass in promise_list:
    # Parse arguments
    upgrader = promise_klass(config_dict)
    if upgrader.isApplicable():
      upgrader.checkConsistency(fixit=not upgrader.config.dry_run)

  sys.exit()

