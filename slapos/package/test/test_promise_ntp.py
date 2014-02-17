
from slapos.package.promise import ntp
import os
import unittest

NTP_CONTENT = """

server 0.ubuntu.pool.ntp.org

"""

def _fake_call(self, *args, **kw):
  self.last_call = (args, kw)

class testPromiseHostnameCase(unittest.TestCase):

  def setUp(self):
    ntp.Promise._call = _fake_call

  def testHostnameCheckConsistency(self):
    promise = ntp.Promise()

    self.assertFalse(promise.checkConsistency(computer_id="TESTING"))

  def testHostnameFixConsistency(self):
    hostname.Promise._call = _fake_call
    promise = ntp.Promise()
    promise.hostname_path = "/tmp/hostname_for_test_fix"

    if os.path.exists(promise.hostname_path):
      os.remove(promise.hostname_path)

    self.assertFalse(promise.checkConsistency(computer_id="TESTING"))
    self.assertTrue(promise.fixConsistency(computer_id="TESTING"))
    self.assertEqual(promise.last_call, 
                     ((['hostname', '-F', '/tmp/hostname_for_test_fix'],), {})
                    )

