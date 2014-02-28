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

import ConfigParser
import os
import time
import traceback
import tempfile
import datetime

from slapos.networkcachehelper import helper_download_network_cached_to_file
from slapos.networkcachehelper import helper_upload_network_cached_from_file


class NetworkCache:
  def __init__(self, configuration_path):
    if not os.path.exists(configuration_path):
      raise ValueError("You need configuration file")
    self.configuration = configuration_path
    self._load()
 
  def _load(self):
    network_cache_info = ConfigParser.RawConfigParser()
    network_cache_info.read(self.configuration)
    network_cache_info_dict = dict(network_cache_info.items('networkcache'))
    def get_(name):
      return network_cache_info_dict.get(name)

    self.download_binary_cache_url = get_('download-binary-cache-url')
    self.download_cache_url = get_('download-cache-url')
    self.download_binary_dir_url = get_('download-binary-dir-url')
    self.signature_certificate_list = get_('signature-certificate-list')

    # Not mandatory
    self.dir_url = get_('upload-dir-url')
    self.cache_url = get_('upload-cache-url')
    self.signature_private_key_file = get_('signature_private_key_file')
    self.shacache_cert_file = get_('shacache-cert-file')
    self.shacache_key_file = get_('shacache-key-file')
    self.shadir_cert_file = get_('shadir-cert-file')
    self.shadir_key_file = get_('shadir-key-file')


    if network_cache_info.has_section('slapupdate'):
      self.directory_key = network_cache_info.get('slapupdate', 'upgrade_key')
    else:
      self.directory_key = "slapos-upgrade-testing-key"

def get_yes_no(prompt):
  while True:
    answer = raw_input(prompt + " [y,n]: ")
    if answer.upper() in ['Y', 'YES']:
        return True
    if answer.upper() in ['N', 'NO']:
        return False

class Signature:

  def __init__(self, config, logger=None):
    self.config = config
    self.logger = logger

  def log(self, message):
    if self.logger is not None:
      self.logger.debug(message)
    else:
      print message

  def _download(self, path):
    """
    Download a tar of the repository from cache, and untar it.
    """
    shacache = NetworkCache(self.config.slapos_configuration)

    if shacache.signature_certificate_list is None:
      raise ValueError("You need at least one valid signature for download")

    def strategy(entry_list):
      """Get the latest entry. """
      timestamp = 0
      best_entry = None
      for entry in entry_list:
        if entry['timestamp'] > timestamp:
          best_entry = entry

      return best_entry

    return helper_download_network_cached_to_file(
      path=path,
      directory_key=shacache.directory_key,
      required_key_list=['timestamp'],
      strategy=strategy,
      # Then we give a lot of not interesting things
      dir_url=shacache.download_binary_dir_url,
      cache_url=shacache.download_binary_cache_url,
      signature_certificate_list=shacache.signature_certificate_list,
    )
  
  def download(self):
    """
    Get status information and return its path
    """
    info, path = tempfile.mkstemp()
    if not self._download(path) == False:
      print open(path).read()
      return path
    else:
      raise ValueError("No result from shacache")

  def _upload(self, path):
    """
    Creates uploads repository to cache.
    """
    shacache = NetworkCache(self.config.slapos_configuration)
 
    metadata_dict = {
      # XXX: we set date from client side. It can be potentially dangerous
      # as it can be badly configured.
      'timestamp': time.time(),
    }
    try:
      if helper_upload_network_cached_from_file(
        path=path,
        directory_key=shacache.directory_key,
        metadata_dict=metadata_dict,
        # Then we give a lot of not interesting things
        dir_url=shacache.dir_url,
        cache_url=shacache.cache_url,
        signature_private_key_file=shacache.signature_private_key_file,
        shacache_cert_file=shacache.shacache_cert_file,
        shacache_key_file=shacache.shacache_key_file,
        shadir_cert_file=shacache.shadir_cert_file,
        shadir_key_file=shacache.shadir_key_file,
      ):
        self.log('Uploaded update file to cache.')
    except Exception:
      self.log('Unable to upload to cache:\n%s.' % traceback.format_exc())

  def upload(self, dry_run=0, verbose=1):
    upgrade_info = ConfigParser.RawConfigParser()
    upgrade_info.read(self.config.upgrade_file)

    tomorrow = datetime.date.today() + datetime.timedelta(days=1)

    if self.config.reboot:
      upgrade_info.set('system', 'reboot', tomorrow.isoformat())
    if self.config.upgrade:
      upgrade_info.set('system', 'upgrade', tomorrow.isoformat())

    file = open(self.config.upgrade_file, "w")
    upgrade_info.write(file)
    file.close()

    if verbose:
      self.log(" You will update this :")
      self.log(open(self.config.upgrade_file).read())

    if dry_run:
      return

    if get_yes_no("Do you want to continue? "):
      self._upload(self.config.upgrade_file)
 
  def update(self, reboot=None, upgrade=None):
    if reboot is None and upgrade is None:
      return 
    if not self.current_state.has_section('system'):
      self.current_state.add_section('system')

    if reboot is not None:
      self.current_state.set('system', 'reboot', reboot)

    if upgrade is not None:
      self.current_state.set('system', 'upgrade', upgrade)
  
    current_state_file = open(self.config.srv_file, "w")
    self.current_state.write(current_state_file)
    current_state_file.close()

  def get_signature_dict(self):
    """ Convert Next state info into a dict """
    map_dict = {}
    for key in self.next_state.sections():
      if key == "system":
        continue
      def clean_list(l):
        return [x.strip() for x in l.split('\n') if x.strip() != '']
      map_dict[key] = {}
      for entry in self.next_state.options(key):
        map_dict[key][entry] = clean_list(self.next_state.get(key, entry))

    return map_dict

  def _read_state(self, state, name):
    """ Extract information from config file """
    if not state.has_section('system'):
      return None
    return datetime.datetime.strptime(
      state.get('system', name), "%Y-%m-%d").date()

  def load(self):
    """
    Extract information from config file and server file
    """
    self.current_state = ConfigParser.RawConfigParser()
    self.current_state.read(self.config.srv_file)

    self.next_state = ConfigParser.ConfigParser()
    self.next_state.read(self.download())

    self.reboot = self._read_state(self.next_state, "reboot")
    self.upgrade = self._read_state(self.next_state, "upgrade")
    self.last_reboot = self._read_state(self.current_state, "reboot")
    self.last_upgrade = self._read_state(self.current_state, "upgrade")
