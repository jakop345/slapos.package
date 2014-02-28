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

import os
import subprocess
import logging
import ConfigParser

# slapos.package imports
from distribution import PackageManager
from signature import Signature

class SlapError(Exception):
  """
  Slap error
  """
  def __init__(self, message):
    self.msg = message


class UsageError(SlapError):
  pass


class ExecError(SlapError):
  pass

# Class containing all parameters needed for configuration
class Config:
  def __init__(self, option_dict=None):
    if option_dict is not None:
      # Set options parameters
      for option, value in option_dict.__dict__.items():
        setattr(self, option, value)

class BasePromise(PackageManager):

  systemctl_path_list = ["/bin/systemctl", 
                         "/usr/bin/systemctl"]

  def __init__(self, config_dict=None):
    self.config = Config(config_dict)

    self.logger = logging.getLogger('')
    self.logger.setLevel(logging.DEBUG)
    # add ch to logger
    #self.logger.addHandler(ch)

    self.signature = None

  def getSignature(self):
    """ Return signature loaded from signature file """
    # Get configuration
    if self.signature is None:
      self.signature = Signature(self.config)
      self.signature.load()

    return self.signature

  def getSlapOSConfigurationDict(self, section="slapos"):
    """ Return a dictionary with the slapos.cfg configuration """

    configuration_info = ConfigParser.RawConfigParser()
    configuration_info.read(self.config.slapos_configuration)

    return dict(configuration_info.items(section))

  def isApplicable(self):
    """ Define if the promise is applicable checking the promise list """
    upgrade_goal = self.getPromiseSectionDict()
    if upgrade_goal is None:
      return False

    if upgrade_goal.get("filter-promise-list") is None:
      # Run all if no filter is provided
      return True

    module = self.__module__.split(".")[-1]
    return module in upgrade_goal.get("filter-promise-list")


  def getPromiseSectionDict(self):
    """ Get the section which matches with the system """
    signature = self.getSignature()
    configuration_dict = signature.get_signature_dict()
    for entry in configuration_dict:
      signature_list = configuration_dict[entry].get("signature-list")
      if self.matchSignatureList(signature_list):
        return configuration_dict[entry]

  def log(self, message):
    """ For now only prints, but it is usefull for test purpose """
    self.logger.info(message)

  def _isSystemd(self):
    """ Dectect if Systemd is used """
    for systemctl_path in self.systemctl_path_list:
      if os.path.exists(systemctl_path):
        return True
    return False

  def _service(self, name, action, stdout=None, stderr=None, dry_run=False):
    """
    Wrapper invokation of service or systemctl by identifying what it is available.
    """
    if self._isSystemd(): 
      self._call(['systemctl', action, name], stdout=stdout, stderr=stderr, dry_run=dry_run)
    else:
      self._call(['service', name, action], stdout=stdout, stderr=stderr, dry_run=dry_run)

  def _call(self, cmd_args, stdout=None, stderr=None, dry_run=False):
    """
    Wrapper for subprocess.call() which'll secure the usage of external program's.

    Args:
    cmd_args: list of strings representing the command and all it's needed args
    stdout/stderr: only precise PIPE (from subprocess) if you don't want the
    command to create output on the regular stream
    """
    self.log("Calling: %s" % ' '.join(cmd_args))

    if not dry_run:
      p = subprocess.Popen(cmd_args, stdout=stdout, stderr=stderr)
      output, err = p.communicate()
      return output, err
