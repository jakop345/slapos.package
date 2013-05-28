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
import argparse
import datetime
import logger
import netuse
import os.path
import pickle
import slapos.slap.slap
import sys
from time import sleep

def parseArgumentTuple():
    parser = argparse.ArgumentParser()
    parser.add_argument("--master-url",
                        help="The master server URL. Mandatory.",
                        required=True)
    parser.add_argument("--computer-id",
                        help="The computer id defined in the server.",
                        required=True)
    parser.add_argument("--cert-file",
                        help="Path to computer certificate file.",
                        default="/etc/slapos/ssl/computer.crt")
    parser.add_argument("--key-file",
                        help="Path to computer key file.",
                        default="/etc/slapos/ssl/computer.key")
    parser.add_argument("--report-interval",
                        help="Interval in seconds to send report to master.",
                        default=300)
    parser.add_argument("--data-file",
                        help="File used to save report data.",
                        default="net_drive_usage_report.data")
    parser.add_argument("--server-name",
                        help="Interval in seconds to send report to master.",
                        default="")
    option = parser.parse_args()

    # Build option_dict
    option_dict = {}

    for argument_key, argument_value in vars(option).iteritems():
        option_dict.update({argument_key: argument_value})

    return option_dict


class NetDriveUsageReporter(object):

    def __init__(self, option_dict):
      for option, value in option_dict.items():
        setattr(self, option, value)
      self.slap = slapos.slap.slap()
      self.slap_computer = None
      self._domain_name = None
      self._domain_account = None
      self._config_id = None
      self._report_date = None
      self._db = initializeDatabase(self.data_file)

    def initializeConnection(self):
        connection_dict = {}
        connection_dict['key_file'] = self.key_file
        connection_dict['cert_file'] = self.cert_file
        self.slap.initializeConnection(self.master_url,
                                       **connection_dict)
        self.slap_computer = self.slap.registerComputer(self.computer_id)

    def initializeConfigData(self):
        user_info = netuser.userInfo()
        self._domain_account = "%s\\%s" % user_info[0:2]

        q = self._db.execute
        s = "SELECT _rowid, report_date FROM config WHERE domain_account=? and computer_id=?"
        r =
        for r in q(s, (self._domain_account, self.computer_id)):
            self._config_id, self._report_date = r
        else:
            q("INSERT OR REPLACE INTO config(domain_account, computer_id, report_date)"
              " VALUES (?,?,?)",
              (self._domain_account, self.computer_id, datetime.now()))
        for r in q(s, (self._domain_account, self.computer_id)):
            self._config_id, self._report_date = r

    def run(self):
        self.initializeConfigData()
        self.initializeConnection()
        current_timestamp = datetime.now()
        try:
            while True:
                last_timestamp = datetime.now()
                d = last_timestamp - current_timestamp
                if d.seconds < self.report_interval:
                    sleep(self.report_interval)
                    continue
                r = self.getUsageReport(d.seconds, current_timestamp)
                current_timestamp = last_timestamp
                self.insertRecord(r[0], r[1], r[2], r[3])
                self.sendReport()
        except KeyboardInterrupt:
            pass

    def getUsageReport(self, duration, timestamp=None):
        if timestamp is None:
            timestamp = datetime.now()
        r = [self.computer_id, self.report_sequence_no, timestamp, duration,
             self._domain_name, self._domain_account, ]
        self.report_sequence_no += 1
        remark = []
        total = 0
        for x in netuse.usageReport(self.server_name):
            total += x[2]
            remark.append(" ".join(map(str, x[0:3])))
        r.append(total)
        r.append("\n".join(remark))
        return r

    def sendReport(self):
        # If report_date is not today, then
        #    Generate xml data from local table by report_date
        #    Send xml data to master node
        #    Change report_date to today
        #    (Optional) Move all the reported data to histroy table
        today = datetime.now()
        if self._report_date < today:
            xml_data = self.generateDailyReport()
            self._postData(xml_data)
            self._db.execute("UPDATE config SET report_date=? where _rowid=?",
                             (today, self._config_id))

    def _postData(self, xml_data):
        """Send a marshalled dictionary of the net drive usage record
        serialized via_getDict.
        """
        self.slap_computer.reportNetDriveUsage(xml_data)

    def initializeDatabase(self, db_path):
        self._db = sqlite3.connect(db_path, isolation_level=None)
        q = self._db.execute
        q("""CREATE TABLE IF NOT EXISTS config (
            domain_account TEXT PRIMARY KEY,
            computer_id TEXT NOT NULL,
            report_date TEXT NOT NULL,
            remark TEXT)""")
        q("""CREATE TABLE IF NOT EXISTS net_drive_usage (
            id INTEGER PRIMARY KEY,
            config_id INTEGER REFERENCES config ( _rowid ),
            drive_letter TEXT NOT NULL,
            remote_folder TEXT NOT NULL,
            start_timestamp TEXT DEFAULT CURRENT_TIMESTAMP,
            duration FLOAT NOT NULL,
            usage_bytes INTEGER,
            remark TEXT)""")
        q("""CREATE TABLE IF NOT EXISTS net_drive_usage_history (
            id INTEGER PRIMARY KEY,
            config_id INTEGER REFERENCES config ( _rowid ),
            drive_letter TEXT NOT NULL,
            remote_folder TEXT NOT NULL,
            start_timestamp TEXT NOT NULL,
            duration FLOAT NOT NULL,
            bytes INTEGER
            remark TEXT)""")

    def insertRecord(self, drive_letter, remote_foler, duration, usage_bytes):
        self._db.execute("INSERT INTO net_drive_usage "
                         "(config_id, drive_letter, remote_folder, duration, usage_bytes )"
                         " VALUES (?, ?, ?, ?, ?)",
                         (self._config_id, drive_letter, remote_folder, duration, usage_bytes))

    def generateDailyReport(self, report_date=None, remove=False):
        if report_date is None:
            report_date = self._report_date
        q = self._db.execute
        xml_data = ""
        for r in q("SELECT * FROM net_drive_usage WHERE start_timestamp=?", report_date):
            pass
        if remove:
            q("INSERT INTO net_drive_usage_history "
              "SELECT * FROM net_drive_usage WHERE start_timestamp=?",
              report_date)
            q("DELETE FROM net_drive_usage WHERE start_timestamp=?",
              report_date)
        return xml_data


def main():
    reporter = NetDriveUsageReporter(parseArgumentTuple())
    reporter.run()

if __name__ == '__main__':
    main()
