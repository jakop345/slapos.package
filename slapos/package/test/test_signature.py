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

from slapos.package import update, signature
import tempfile
import unittest

SIGNATURE = "-----BEGIN CERTIFICATE-----\nXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX\n-----END CERTIFICATE-----"

UPDATE_CFG_DATA = """
[slapupdate]
upgrade_key = slapos-upgrade-testing-key-with-config-file

[networkcache]
download-binary-cache-url = http://www.shacache.org/shacache
download-cache-url = https://www.shacache.org/shacache
download-binary-dir-url = http://www.shacache.org/shadir

signature-certificate-list = -----BEGIN CERTIFICATE-----
  XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
  -----END CERTIFICATE-----


"""

UPDATE_CFG_WITH_UPLOAD_DATA = UPDATE_CFG_DATA + """
signature_private_key_file = /etc/opt/slapos/signature.key
signature_certificate_file = /etc/opt/slapos/signature.cert
upload-cache-url = https://www.shacache.org/shacache
shacache-cert-file = /etc/opt/slapos/shacache.crt
shacache-key-file = /etc/opt/slapos/shacache.key
upload-dir-url = https://www.shacache.org/shadir
shadir-cert-file = /etc/opt/slapos/shacache.crt
shadir-key-file = /etc/opt/slapos/shacache.key
"""


class NetworkCacheTestCase(unittest.TestCase):

  def test_basic(self):
    info, self.configuration_file_path = tempfile.mkstemp()
    open(self.configuration_file_path, 'w').write(UPDATE_CFG_DATA)
    shacache = signature.NetworkCache(self.configuration_file_path)
    self.assertEqual(shacache.download_binary_cache_url,
                     "http://www.shacache.org/shacache")
    self.assertEqual(shacache.download_cache_url,
                     "https://www.shacache.org/shacache")
    self.assertEqual(shacache.download_binary_dir_url,
                     "http://www.shacache.org/shadir")

    self.assertEqual(shacache.signature_certificate_list,
                     SIGNATURE)            

    self.assertEqual(shacache.directory_key,
                     'slapos-upgrade-testing-key-with-config-file')
    # Check keys that don't exist
    # Not mandatory
    self.assertEqual(shacache.dir_url , None)
    self.assertEqual(shacache.cache_url , None)
    self.assertEqual(shacache.signature_private_key_file , None)
    self.assertEqual(shacache.shacache_cert_file , None)
    self.assertEqual(shacache.shacache_key_file , None)
    self.assertEqual(shacache.shadir_cert_file , None)
    self.assertEqual(shacache.shadir_key_file , None)


  def test_with_upload(self):
    info, self.configuration_file_path = tempfile.mkstemp()
    open(self.configuration_file_path, 'w').write(UPDATE_CFG_WITH_UPLOAD_DATA)
    shacache = signature.NetworkCache(self.configuration_file_path)
    self.assertEqual(shacache.download_binary_cache_url,
                     "http://www.shacache.org/shacache")
    self.assertEqual(shacache.download_cache_url,
                     "https://www.shacache.org/shacache")
    self.assertEqual(shacache.download_binary_dir_url,
                     "http://www.shacache.org/shadir")

    self.assertEqual(shacache.signature_certificate_list,
                     SIGNATURE)            

    self.assertEqual(shacache.directory_key,
                     'slapos-upgrade-testing-key-with-config-file')
    # Check keys that don't exist
    # Not mandatory
    self.assertEqual(shacache.dir_url , 'https://www.shacache.org/shadir')
    self.assertEqual(shacache.cache_url , 'https://www.shacache.org/shacache')
    self.assertEqual(shacache.shacache_cert_file , '/etc/opt/slapos/shacache.crt')
    self.assertEqual(shacache.shacache_key_file , '/etc/opt/slapos/shacache.key')
    self.assertEqual(shacache.shadir_cert_file , '/etc/opt/slapos/shacache.crt')
    self.assertEqual(shacache.shadir_key_file , '/etc/opt/slapos/shacache.key')

    self.assertEqual(shacache.signature_private_key_file ,'/etc/opt/slapos/signature.key')

  def test_file_dont_exist(self):
    self.assertRaises(ValueError, signature.NetworkCache, 
                          "/abc/123")

