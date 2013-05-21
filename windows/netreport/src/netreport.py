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
#
# Paramters:
#
#   computer_id, which computer sends this report
#
#   server_name, if it's not empty, only the net drives in this server
#   will be involved in the report.
#
#   report_internal, in seconds
#
#   data_file, save report state and unsending records last time, pickle format.
#
# main process
#
#   read data from data file (pickle)
#
#   check start state, there are 3 cases
#
#       case 1: first report
#
#         Send init report to server
#
#       case 2: normal report
#
#       case 3: unexpected error
#
#         Request server to send back last report information
#
#   If there are unsend reports in json file, send them first
#
#   Start sending report thread, the thread will enter loop as the following:
#
#     Are there unsend records?
#
#       Yes, send those.
#
#           Resend failed, insert the records in the current buffer to unsending queue.
#
#       No.
#
#     Send records in the current buffer
#
#       Failed, insert all the records in the currnet buffer to unsending queue.
#
#     If main process quit?
#
#   Enter main loop:
#
#     If report interval is out,
#
#       Yes, insert a record to the current bffer
#
#       No, sleep for (report_interval / 2 + 1) seconds
#
#     If user wants to quit
#
#       Yes, break main loop
#
#   After quit from main loop,
#
#     Stop sending report thread
#
#     Save unsending queue, report id and state to pickle file.
#
#
#   Interface of computer:
#
#     reportNetDriveUsage will post a list of record:
#
#       (computer_id, sequence_no, timestamp, duration,
#        domain, user, usage, remark)
#
#     getReportSequenceNo?computer_id=XXXX
#     
import argparse
from datetime import datetime
import logger
import netuse
import os.path
import pickle
import Queue
import slapos.slap.slap
import sys
from time import sleep

REPORT_STATE_INIT = 0
REPORT_STATE_RUNNING = 1
REPORT_STATE_STOP = 2

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

    queue_size = 512

    def __init__(self, option_dict):
      for option, value in option_dict.items():
        setattr(self, option, value)
      self.slap = slapos.slap.slap()
      self.slap_computer = None
      self.report_sequence_no = 0
      self._queue = None
      self._state_file = self.data_file + ".state"
      self._domain_name = None
      self._domain_account = None

    def initializeConnection(self):
        connection_dict = {}
        connection_dict['key_file'] = self.key_file
        connection_dict['cert_file'] = self.cert_file
        self.slap.initializeConnection(self.master_url,
                                       **connection_dict)
        self.slap_computer = self.slap.registerComputer(self.computer_id)

    def _getUserInfo(self):
        user_info = netuser.userInfo()
        self._domain_name = user_info[1]
        self._domain_account = user_info[0]

    def run(self):
        self._getUserInfo()
        self.initializeConnection()
        self._loadReportState()
        self._sendReportInQueue()
        self.report_state = REPORT_STATE_RUNNING
        pickle.dump(self.report_state, self._state_file)
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
                if not self.sendUsageReport(r):
                    break
        except KeyboardInterrupt:
            pass
        self._saveReportState()
        self.report_state = REPORT_STATE_STOP
        pickle.dump(self.report_state, self._state_file)

    def _loadReportState(self):
        if not os.path.exists(self.data_file):
            s = {
                "sequence-no" : -1,
                "computer-id" : self.computer_id,
                "queue" : [],                
                }
            pickle.dump(s, self.data_file)
        else:
            s = pickle.load(self.data_file)

        if not s.get("computer-id", "") == self.computer_id:
            pass # data file is not expected

        if s.get("state", None) == REPORT_STATE_RUNNING:
            pass # get sequence no from master sever

        self.report_sequence_no = s["sequence-no"]
        self._queue = s["queue"]

    def _saveReportState(self):
        s = {
            "computer-id" : self.computer_id,
            "sequence-no" : self.report_sequence_no,
            "queue" : self._queue,
            }
        pickle.dump(s, self.data_file)

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

    def sendUsageReport(self, r):
        self._queue[0:0] = [r]
        return self._sendReportInQueue()
            
    def _postData(self, r):
        """Send a marshalled dictionary of the net drive usage record
        serialized via_getDict.
        """
        self.slap_computer.reportNetDriveUsage(r)

    def _sendReportInQueue(self):
        try:
            while True:
                r = self._queue[-1]
                if not self._postData(r):
                    return False
                self._queue.pop()
        except IndexError:
            pass
        return True

def main():
    reporter = NetDriveUsageReporter(parseArgumentTuple())
    reporter.run()

if __name__ == '__main__':
    main()
