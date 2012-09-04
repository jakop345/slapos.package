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
import urllib2

# create console handler and set level to debug
ch = logging.StreamHandler()
ch.setLevel(logging.WARNING)
# create formatter
formatter = logging.Formatter("%(levelname)s - %(name)s - %(message)s")
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
        Option("--server-url",
               default='https://perso.telecom-paristech.fr/~leninivi/update-info',
               help="status file url"),        
        Option("--srv-file",
               default='/srv/slapupdate',
               help="Server status file."),        
        Option("-v","--verbose",
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




def _call(cmd_args, stdout=sub.PIPE, stderr=sub.PIPE, dry_run=False):
  """
  Wrapper for subprocess.call() which'll secure the usage of external program's.

  Args:
  cmd_args: list of strings representing the command and all it's needed args
  stdout/stderr: only precise PIPE (from subprocess) if you don't want the
  command to create output on the regular stream
  """
  print ("Calling: %s" % ' '.join(cmd_args))

  if not dry_run :
    p = sub.Popen(cmd_args,stdout=stdout,stderr=stderr)
    output,err = p.communicate()
    return output,err


def suse_version(): 
  """
  Return OpenSUSE version if it is SuSE
  """
  if os.path.exists('/etc/SuSE-release') :
    with open('/etc/SuSE-release') as f :
      for line in f:
        if "VERSION" in line:
          dist = line.split()
          return float(dist[2])
  else :
    return 0


def repositories_purge ():
  """
  Remove all repositories
  """
  listing,err = _call(['zypper','lr'])
  while listing.count('\n') > 2 :
    output,err = _call(['zypper','rr','1'],stdout=None)
    listing,err = _call(['zypper','lr'])


def repositories_add (url,alias):
  """ Add a repository """
  output,err = _call(['zypper','ar','-fc',url,alias],stdout=None)



def update_software ():
  """ Upgrade softwares """
  _call(['zypper','--gpg-auto-import-keys','up','-l']
        , stdout=None)

def update_system ():
  """ Dist-Upgrade of system """
  _call(['zypper','--gpg-auto-import-keys','dup','-l'], stdout = None)



def get_info_from_master(config):
  """
  Get status information and return its path
  """
  update_server_url = config.server_url
  request = urllib2.Request(update_server_url)
  url = urllib2.urlopen(request)  
  page = url.read()
  info, path = tempfile.mkstemp()
  update_info = open(path,'w')
  update_info.write(page)
  update_info.close()
  return path




def repositories_process(repositories):
  """
  Remove and then add needed repositories
  """
  repositories_purge()
  for key in repositories :
    repositories_add(repositories[key],key)


def save_current_state(current_state,config):
  """
  Will save ConfigParser to config file
  """
  file = open(config.srv_file,"w")
  current_state.write(file)
  file.close()

def update_machine(config):
  """
  Will fetch information from web and update and/or reboot
  machine if needed
  """
  # Define logger for update_machine
  logger = logging.getLogger('Updating your machine')
  logger.setLevel(logging.DEBUG)
  # add ch to logger
  logger.addHandler(ch)

  # Get configuration 
  current_state = ConfigParser.RawConfigParser()
  current_state.read(config.srv_file)
  next_state = ConfigParser.RawConfigParser()
  next_state_file = get_info_from_master(config)
  next_state.read(next_state_file)
  os.remove(next_state_file)
  config.getSystemInfo(current_state,next_state)
  config.displayConfig()

  # Check if run for first time
  if config.first_time:
    current_state.add_section('system')
    current_state.set('system','reboot',config.today.isoformat())
    current_state.set('system','upgrade',config.today.isoformat())
    save_current_state(current_state,config)
    # Purge repositories list and add new ones
    repositories_process(dict(next_state.items('repositories')))
    # Check if dist-upgrade is needed
    if suse_version() < config.opensuse_version:
      logger.info("We will now upgrade your system")
      update_system()
      os.system('reboot')
    else :
      logger.info("We will now upgrade your packages")
      update_software()
      os.system('reboot')
  else:
    if config.last_upgrade < config.upgrade :
      # Purge repositories list and add new ones
      repositories_process(dict(next_state.items('repositories')))

      current_state.set('system','upgrade',config.today.isoformat())
      save_current_state(current_state,config)
      if suse_version() < config.opensuse_version:
        logger.info("We will now upgrade your system")
        update_system()
      else:
        logger.info("We will now upgrade your packages")
        update_software()
    else :
      logger.info("Your system is up to date")
      
    if config.last_reboot < config.reboot :
      current_state.set('system','reboot',config.today.isoformat())
      save_current_state(current_state,config)
      print "reboot"
      os.system('reboot')
      
      




# Class containing all parameters needed for configuration
class Config:
  def setConfig(self, option_dict):
    """
    Set options given by parameters.
    """
    # Set options parameters
    for option, value in option_dict.__dict__.items():
      setattr(self, option, value)

    self.today = datetime.date.today()

    # Define logger for register
    self.logger = logging.getLogger('slapupdate configuration')
    self.logger.setLevel(logging.DEBUG)
    # add ch to logger
    self.logger.addHandler(ch)

    if self.verbose :
      ch.setLevel(logging.DEBUG)

  def getSystemInfo(self,current_state,next_state):
    """
    Extract information from config file and server file
    """
    self.reboot = datetime.datetime.strptime(next_state.get('system','reboot'),
                                             "%Y-%m-%d").date()
    self.upgrade = datetime.datetime.strptime(next_state.get('system','upgrade'),
                                              "%Y-%m-%d").date()
    self.opensuse_version = next_state.getfloat('system','opensuse_version')
    if not current_state.has_section('system'):
      self.first_time = True
    else:
      self.first_time = False
      self.last_reboot = datetime.datetime.strptime(
        current_state.get('system','reboot'),
        "%Y-%m-%d").date()
      self.last_upgrade = datetime.datetime.strptime(
        current_state.get('system','upgrade'),
        "%Y-%m-%d").date()

  def displayConfig(self):
    """
    Display Config
    """
    self.logger.debug( "reboot %s" % self.reboot)
    self.logger.debug( "upgrade %s" % self.upgrade)
    self.logger.debug( "suse version %s" % self.opensuse_version)
    if not self.first_time :
      self.logger.debug( "Last reboot : %s" % self.last_reboot)
      self.logger.debug( "Last upgrade : %s" % self.last_upgrade)

      


def main():
  """Update computer and slapos"""
  usage = "usage: %s [options] " % sys.argv[0]
  # Parse arguments
  config = Config()
  config.setConfig(Parser(usage=usage).check_args())
  #config.displayUserConfig()
  update_machine(config)
  sys.exit()
