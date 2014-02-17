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
import os
import tempfile

from slapos.networkcachehelper import helper_download_network_cached_to_file


class NetworkCache:
  def __init__(self, configuration):
    if not os.path.exists(slapos_conf):
      raise ValueError("You need configuration file")
    self.configuration = configuration

  def _load(self):
    
    network_cache_info = ConfigParser.RawConfigParser()
    network_cache_info.read(self.configuration)
    self.download_binary_cache_url = network_cache_info.get('networkcache', 'download-binary-cache-url')
    self.download_cache_url = network_cache_info.get('networkcache', 'download-cache-url')
    self.download_binary_dir_url = network_cache_info.get('networkcache', 'download-binary-dir-url')
    self.signature_certificate_list = network_cache_info.get('networkcache', 'signature-certificate-list')

    if network_cache_info.has_section('slapupdate'):
      self.directory_key = network_cache_info.get('slapupdate', 'upgrade_key')
    else:
      self.directory_key = "slapos-upgrade-testing-key"

class Signature:

  def __init__(self, config, logger=None):
    self.config = config
    self.logger = logger
    self.current_state_path = config.srv_file

    # Get configuration
    self.current_state = ConfigParser.RawConfigParser()
    self.current_state.read(config.srv_file)
  
    self.next_state = ConfigParser.RawConfigParser()
    self.next_state.read(self.download())
  
  def _download(self, path):
    """
    Download a tar of the repository from cache, and untar it.
    """
    shacache = NetworkCache(self.config.slapos_configuration)

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

  def update(self, reboot=None, upgrade=None):
    if reboot is None and upgrade is None:
      return 
    if not self.current_state.has_section('system'):
      self.current_state.add_section('system')

    if reboot is not None:
      self.current_state.set('system', 'reboot', reboot)

    if upgrade is not None:
      self.current_state.set('system', 'upgrade', upgrade)
  
    current_state_file = open(self.current_state_path, "w")
    self.current_state.write(current_state_file)
    current_state_file.close()

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
    self.reboot = self._read_state(self.next_state, "upgrade")
    self.upgrade = self._read_state(self.next_state, "upgrade")
    self.last_reboot = self._read_state(self.current_state, "reboot")
    self.last_upgrade = self._read_state(self.current_state, "upgrade")
