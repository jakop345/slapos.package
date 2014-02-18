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





