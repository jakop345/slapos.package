
from slapos.package.promise import hostname
import os
import unittest

def _fake_call(self, *args, **kw):
  self.last_call = (args, kw)

class testPromiseHostnameCase(unittest.TestCase):

  def setUp(self):
    hostname.Promise._call = _fake_call

  def testHostnameCheckConsistency(self):
    promise = hostname.Promise()
    promise.configuration_file_path = "/tmp/hostname_for_test"

    self.assertFalse(promise.checkConsistency(computer_id="TESTING"))

  def testHostnameFixConsistency(self):
    hostname.Promise._call = _fake_call
    promise = hostname.Promise()
    promise.hostname_path = "/tmp/hostname_for_test_fix"

    if os.path.exists(promise.hostname_path):
      os.remove(promise.hostname_path)

    self.assertFalse(promise.checkConsistency(computer_id="TESTING"))
    self.assertTrue(promise.fixConsistency(computer_id="TESTING"))
    self.assertEqual(promise.last_call, 
                     ((['hostname', '-F', '/tmp/hostname_for_test_fix'],), {})
                    )
