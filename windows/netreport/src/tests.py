# -*- coding: utf-8 -*-

import sys
import os
import tempfile
import shutil

sys.path.insert(0, os.getcwd())

import test.test_support
netuse = test.test_support.import_module('netuse')
threading = test.test_support.import_module('threading')
import unittest

class BaseTestCase(unittest.TestCase):
    def setUp(self):
        self._threads = test.test_support.threading_setup()

    def tearDown(self):
        test.test_support.threading_cleanup(*self._threads)
        test.test_support.reap_children()

class NetUsageTests(BaseTestCase):

    def test_user_info(self):
        u = netuse.userinfo()
        self.assertEquals(len(u), 3)
        self.assertEquals(u, [])

    def test_usage_report(self):
        r = netuse.usagereport()
        self.assertEquals(len(r), 0)
        self.assertEquals(r, [])

    def test_usage_report_server(self):
        r = netuse.usagereport('myserver')
        self.assertEquals(len(r), 0)
        self.assertEquals(r, [])

if __name__ == "__main__":
    # unittest.main()
    loader = unittest.TestLoader()
    # loader.testMethodPrefix = 'test_'
    suite = loader.loadTestsFromTestCase(NetUsageTests)
    unittest.TextTestRunner(verbosity=2).run(suite)
