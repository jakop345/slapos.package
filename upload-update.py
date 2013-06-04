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
from optparse import OptionParser, Option
import traceback
import sys
import time

from slapos.networkcachehelper import helper_upload_network_cached_from_file


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
        Option("--upgrade-file",
               default='/etc/slapos-cache/slapos-upgrade',
               help="File use as reference to upgrade."),
        Option("-u","--upgrade",
               default=False,
               action="store_true",
               help="If selected will update tomorrow."),
        Option("-r","--reboot",
               default=False,
               action="store_true",
               help="If selected will reboot tomorrow."),
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



# Utility fonction to get yes/no answers
def get_yes_no (prompt):
  while True:
    answer=raw_input( prompt + " [y,n]: " )
    if answer.upper() in [ 'Y','YES' ]: return True
    if answer.upper() in [ 'N', 'NO' ]: return False



def upload_network_cached_from_file(path, networkcache_options):
  """
  Creates uploads repository to cache.
  """
  print 'Uploading update'
  # XXX create a file descriptor from string. (simplest way: create tmpfile and write)

  metadata_dict = {
    # XXX: we set date from client side. It can be potentially dangerous
    # as it can be badly configured.
    'timestamp':time.time(),
  }
  try:
    if helper_upload_network_cached_from_file(
      path=path,
      directory_key='slapos-upgrade',
      metadata_dict=metadata_dict,
      # Then we give a lot of not interesting things
      dir_url=networkcache_options.get('upload-dir-url'),
      cache_url=networkcache_options.get('upload-cache-url'),
      signature_private_key_file=networkcache_options.get(
        'signature_private_key_file'),
      shacache_cert_file=networkcache_options.get('shacache-cert-file'),
      shacache_key_file=networkcache_options.get('shacache-key-file'),
      shadir_cert_file=networkcache_options.get('shadir-cert-file'),
      shadir_key_file=networkcache_options.get('shadir-key-file'),
    ):
      print 'Uploaded update file to cache.'
  except Exception:
    print 'Unable to upload to cache:\n%s.' % traceback.format_exc()

def save_current_state(current_state,config):
  """
  Will save ConfigParser to config file
  """
  file = open(config.upgrade_file,"w")
  current_state.write(file)
  file.close()

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
    self.tomorrow = self.today + datetime.timedelta(days=1)


def new_upgrade (config):
  upgrade_info = ConfigParser.RawConfigParser()
  upgrade_info.read(config.upgrade_file)
  if config.reboot :
    upgrade_info.set('system','reboot',config.tomorrow)
  if config.upgrade :
    upgrade_info.set('system','upgrade',config.tomorrow)
  save_current_state(upgrade_info,config)  
  print " You will update this :"
  print open(config.upgrade_file,'r').read()
  if not get_yes_no("Do you want to continue? "):
    sys.exit(0)

  networkcache_info = ConfigParser.RawConfigParser()
  networkcache_info.read('/etc/slapos-cache/slapos.cfg')
  networkcache_info_dict = dict(networkcache_info.items('networkcache'))
  if not config.dry_run:
    upload_network_cached_from_file(config.upgrade_file,networkcache_info_dict)



def main():
  """Upload file to update computer and slapos"""
  usage = "usage: [options] "
  # Parse arguments
  config = Config()
  config.setConfig(Parser(usage=usage).check_args())
  new_upgrade(config)
  sys.exit()



if __name__ == '__main__':
  main ()
