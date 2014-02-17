#!/usr/bin/python
# -*- coding: utf-8 -*-
##############################################################################
#
# Copyright (c) 2012 Vifib SARL and Contributors.
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

import ConfigParser
import datetime
import logging
from optparse import OptionParser, Option
import os
import subprocess as sub
import sys
import tempfile

# create console handler and set level to warning
ch = logging.StreamHandler()
ch.setLevel(logging.WARNING)
# create formatter
formatter = logging.Formatter("%(asctime)s - %(levelname)s - %(name)s - %(message)s")
# add formatter to ch
ch.setFormatter(formatter)

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

# Class containing all parameters needed for configuration
class Config:
  def __init__(self, option_dict):
    # Set options parameters
    for option, value in option_dict.__dict__.items():
      setattr(self, option, value)

class Upgrader:
  def __init__(self, config_dict):
    # Set options parameters
    self.config = Config(config_dict)

    self.logger = logging.getLogger('Updating your machine')
    self.logger.setLevel(logging.DEBUG)
    # add ch to logger
    self.logger.addHandler(ch)


  def checkConsistency(self, *args, **kw):
    print "CHECK CONSISTENCY %s" % ((args, kw),)

  def run(self):
    """
    Will fetch information from web and update and/or reboot
    machine if needed
    """
    today = datetime.date.today().isoformat()
  
    # Get configuration
    signature = Signature(self.config)
  
    signature.load()
  
    self.logger.debug("Expected Reboot early them %s" % signature.reboot)
    self.logger.debug("Expected Upgrade early them %s" % signature.upgrade)
    self.logger.debug("Last reboot : %s" % signature.last_reboot)
    self.logger.debug("Last upgrade : %s" % signature.last_upgrade)
  
    # Check if run for first time
    if signature.last_reboot is None:
      signature.update(reboot=today, upgrade=today)
  
      # Purge repositories list and add new ones
      self.checkConsistency()
    else:
      if signature.last_upgrade < signature.upgrade:
        # Purge repositories list and add new ones
  
        signature.update(upgrade=today)
        self.checkConcistency()
      else:
        logger.info("Your system is up to date")
  
      if signature.last_reboot < signature.reboot:
        signature.update(reboot=today)
  
def main():
  """Update computer and slapos"""
  usage = "usage: %s [options] " % sys.argv[0]
  # Parse arguments
  upgrader = Upgrader(Parser(usage=usage).check_args())
  upgrader.run()
  sys.exit()
