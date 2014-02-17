
from slapos.package.base_promise import BasePromise
import os
import unittest

def _fake_call(self, *args, **kw):
  self.last_call = args

class testBasePromiseCase(unittest.TestCase):

  def setUp(self):
    BasePromise._call = _fake_call

  def testIsSystemd(self):
    promise = BasePromise()
    systemctl_path = "/tmp/_testBasePromiseCase_systemctl_test"
    promise.systemctl_path_list = ["/tmp/_testBasePromiseCase_systemctl_test"]
    if os.path.exists(systemctl_path):
      os.remove(systemctl_path)

    self.assertFalse(promise._isSystemd())

    open(systemctl_path, "w").write("echo test")
    self.assertTrue(promise._isSystemd())

  def testSystemctl(self):
    promise = BasePromise()
    def _fake_true_isSystemd():
      return True

    promise._isSystemd = _fake_true_isSystemd

    promise._service("service_name", "service_action")

    self.assertEqual(promise.last_call, 
             (['systemctl', 'service_action', 'service_name'],))

  def testService(self):
    promise = BasePromise()
    def _fake_false_isSystemd():
      return False

    promise._isSystemd = _fake_false_isSystemd

    promise._service("service_name", "service_action")

    self.assertEqual(promise.last_call, 
                     (['service', 'service_name', 'service_action'],))

