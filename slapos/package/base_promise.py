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
from distribution import PackageManager

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

class BasePromise(PackageManager):

  systemctl_path_list = ["/bin/systemctl", 
                         "/usr/bin/systemctl"]

  def log(self, message):
    """ For now only prints, but it is usefull for test purpose """
    print message

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

class BasePackagePromise(BasePromise):

  package_name = None
  binary_path = None

  def checkConsistency(self, fixit=0, **kw):
    is_ok = True
    if self.binary is not None and \
        not os.path.exists(self.binary_path):
      is_ok = False

    if self._isUpgradable(self.package_name):
      is_ok = False

    if not is_ok and fixit:
      return self.fixConsistency(**kw)

    return is_ok

  def fixConsistency(self, **kw):
    self._installSoftware(self.package_name)
    return self.checkConsistency(fixit=0, **kw)
