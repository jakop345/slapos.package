# -*- coding: utf-8 -*-
##############################################################################
#
# Copyright (c) 2010 Vifib SARL and Contributors. All Rights Reserved.
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

from optparse import OptionParser, Option
import ConfigParser
import os
import pkg_resources
import pwd
import socket
import subprocess
import sys
import time
import urllib2

import iniparse

SLAPOS_MARK = '# Added by SlapOS\n'


class Parser(OptionParser):

  def __init__(self, usage=None, version=None):
    """
    Initialize all possible options.
    """
    OptionParser.__init__(self, usage=usage, version=version,
            option_list=[
                Option("-u", "--update",
                    default=False,
                    action="store_true",
                    help="Will only run an update for scripts."),
                Option("-v", "--verbose",
                    default=False,
                    action="store_true",
                    help="Verbose output."),
                Option("-n", "--dry-run",
                    help="Simulate the execution steps",
                    default=False,
                    action="store_true"),
                ]
            )

  def check_args(self):
    """
    Check arguments
    """
    (options, args) = self.parse_args()
    return options


class SlapError(Exception):
  """
  Slap error
  """
  def __init__(self, message):
    self.msg = message


class UsageError(SlapError):
  pass


class ExecError(SlapError):
  pass


def _call(cmd_args, stdout=None, stderr=None, dry_run=False):
  """
  Wrapper for subprocess.call() which'll secure the usage of external program's.

  Args:
  cmd_args: list of strings representing the command and all it's needed args
  stdout/stderr: only precise PIPE (from subprocess) if you don't want the
  command to create output on the regular stream
  """
  print "Calling: %s" % ' '.join(cmd_args)
  try:
    if subprocess.call(cmd_args, stdout=stdout, stderr=stderr) != 0:
      raise ValueError('Issues during running %r' % cmd_args)
  except OSError as e:
    raise ExecError('Process responded: "%s" when calling "%s"' %
                      (e, ' '.join(cmd_args)))


# Utility function to get yes/no answers
def get_yes_no(prompt, default=None):
  if default:
    def_value = '/ Default yes'
  elif default is False:
    def_value = '/ Default no'
  else:
    def_value = ''
  while True:
    answer = raw_input(prompt + " [y,n] %s: " % def_value)
    if answer.upper() in ['Y', 'YES']:
      return True
    if answer.upper() in ['N', 'NO']:
      return False
    if not answer and default is not None:
        return default


def getSlaposConfiguration(slapos_configuration_file_path=None):
  config = ConfigParser.RawConfigParser()
  # Search slapos.cfg
  if not slapos_configuration_file_path:
    slapos_configuration_file_path = "/etc/opt/slapos/slapos.cfg"
  slapos_configuration_file_path_old = "/etc/slapos/slapos.cfg"

  if not os.path.isfile(slapos_configuration_file_path):
    if os.path.isfile(slapos_configuration_file_path_old):
      slapos_configuration_file_path = slapos_configuration_file_path_old
    else:
      # No configuration found : returning
      return {}
  # Reading slapos paths from configuration file
  config.read(slapos_configuration_file_path)
  return config


# Return OpenSUSE version if it is SuSE
def suse_version():
  if not os.path.exists('/etc/SuSE-release'):
    return 0
  with open('/etc/SuSE-release') as f:
    for line in f:
      if "VERSION" in line:
        dist = line.split()
        return float(dist[2])


# Parse certificate to get computer name and return it
def get_computer_name(slapos_configuration):
  try:
    return getSlaposConfiguration(slapos_configuration).get('slapos',
                                                            'computer_id')
  except:
    print "Warning: slapos.cfg doesn't exist. Using current hostname."
  return socket.gethostname()


def setup_bridge(slapos_configuration, create_tap):
  slapos_cfg_path = os.path.join(slapos_configuration, 'slapos.cfg')

  # using iniparse instead of ConfigParser, will retain the comments
  slapos_cfg = iniparse.RawConfigParser()
  slapos_cfg.read(slapos_cfg_path)

  slapos_cfg.set('slapformat', 'create_tap', 'true' if create_tap else 'false')
  with open(slapos_cfg_path, 'w') as fout:
    slapos_cfg.write(fout)


# Function to get ssh key
def get_ssh(temp_dir):
  # Downloading ssh_key
  count = 10
  gotten = True
  while count > 0:
    try:
      print "Enter the url of your public ssh key"
      ssh_web = raw_input('-->  ')
      try:
        ssh_key_all = urllib2.urlopen(''.join(ssh_web))
        gotten = True
      except ValueError:
      # add http:// if it is missing (needed by urllib2)
        ssh_web = """http://""" + ssh_web
        ssh_key_all = urllib2.urlopen(''.join(ssh_web))
        gotten = True
    except urllib2.URLError:
      print "  URL ERROR"
      gotten = False
      count -= 1
    if gotten:
      ssh_pub_key = ssh_key_all.read()
      print ssh_pub_key
      if get_yes_no('Is this your ssh public key?'):
        break
      else:
        count -= 1
  ssh_file = open(os.path.join(temp_dir, "authorized_keys"), "w")
  ssh_file.write(''.join(ssh_pub_key))
  ssh_file.close()
  return 0


def remove_former_scripts(slapos_configuration):
  """
  Will remove former scripts
  """
  # Remove old-fashioned slapos service
  try:
    _call(['systemctl', 'disable', 'slapos.service'])
  except:
    pass
  _call(['rm', '-f', os.path.join(slapos_configuration, 'slapos')])
  _call(['rm', '-f', '/etc/systemd/system/slapos.service'])

  _call(['rm', '-f', '/etc/openvpn/client.conf'])
  _call(['rm', '-rf', '/etc/openvpn/keys/'])
  _call(['rm', '-f', os.path.join(slapos_configuration, 'run_slapformat')])


# Specific function to configure SlapOS Image
def slapserver(config):
  dry_run = config.dry_run
  mount_dir_path = config.mount_dir_path
  try:
    # Setting hostname
    hostname_path = os.path.normpath('/'.join([mount_dir_path,
                                               config.hostname_path]))
    print "Setting hostname in : %s" % hostname_path
    if not dry_run:
      open(hostname_path, 'w').write("%s\n" % config.computer_id)

    # Adding the hostname as a valid address
    host_path = os.path.normpath('/'.join([mount_dir_path,
                                           config.host_path]))
    print "Creating %r" % host_path
    if not dry_run:
      open(host_path, 'w').write(
        pkg_resources.resource_stream(__name__,
                                      'template/hosts.in').read() % dict(
          computer_id=config.computer_id))

    # Creating safe sshd_config
    sshd_path = os.path.normpath('/'.join([mount_dir_path, 'etc', 'ssh',
                                           'sshd_config']))
    print "Creating %r" % sshd_path
    if not dry_run:
      open(sshd_path, 'w').write(
        pkg_resources.resource_stream(__name__,
                                      'template/sshd_config.in').read())
      os.chmod(sshd_path, 0600)

    # Creating default bridge config
    br0_path = os.path.normpath('/'.join([mount_dir_path, 'etc',
                                          'sysconfig', 'network', 'ifcfg-br0']))
    print "Creating %r" % br0_path
    if not dry_run:
      open(br0_path, 'w').write(
        pkg_resources.resource_stream(__name__,
                                      'template/ifcfg-br0.in').read())

    # Creating default limits config
    limits_conf_path = os.path.join(mount_dir_path,
                                    'etc', 'security', 'limits.conf')
    print "Overriding %s" % limits_conf_path
    if not dry_run:
      open(limits_conf_path, 'w').write(
        pkg_resources.resource_stream(__name__,
                                      'template/limits.conf.in').read())

    # Writing ssh key
    if config.need_ssh:
      user_path = os.path.normpath('/'.join([mount_dir_path, 'root']))
      ssh_key_directory = os.path.normpath('/'.join([user_path, '.ssh']))
      ssh_key_path = os.path.normpath('/'.join([ssh_key_directory,
                                                'authorized_keys']))
      stat_info = os.stat(user_path)
      uid, gid = stat_info.st_uid, stat_info.st_gid
      ssh_key_directory = os.path.dirname(ssh_key_path)
      if not os.path.exists(ssh_key_directory):
        print "Creating ssh directory: %s" % ssh_key_directory
        if not dry_run:
          os.mkdir(ssh_key_directory)
      if not dry_run:
        print "Setting uid:gid of %r to %s:%s" % (ssh_key_directory, uid, gid)
        os.chown(ssh_key_directory, uid, gid)
        os.chmod(ssh_key_directory, 0700)

      print "Creating file: %s" % ssh_key_path
      if not dry_run:
        open(ssh_key_path, 'a').write(''.join(open(config.key_path, 'r').read()))

      if not dry_run:
        print "Setting uid:gid of %r to %s:%s" % (ssh_key_path, uid, gid)
        os.chown(ssh_key_path, uid, gid)
        os.chmod(ssh_key_path, 0600)

    # Put file to  force VPN if user asked
    if config.force_slapcontainer:
      if not dry_run:
        open(os.path.join(config.slapos_configuration, 'SlapContainer-needed'), 'w')

    # Adding slapos_firstboot in case of MultiDisk usage
    if not config.one_disk:
      for script in ['slapos_firstboot']:
        path = os.path.join(mount_dir_path, 'etc', 'init.d', script)
        print "Creating %r" % path
        if not dry_run:
          open(path, 'w').write(pkg_resources.resource_stream(__name__,
                                                              'script/%s' % script).read())
          os.chmod(path, 0755)
    else:
      for script in ['slapos_firstboot']:
        path = os.path.join(mount_dir_path, 'etc', 'init.d', script)
        if os.path.exists(path):
          print "Removing %r" % path
          if not dry_run:
            os.remove(path)

    # Disable login by password for root
    _call(['passwd', '-d', 'root'])

  finally:
    print "SlapOS Image configuration: DONE"
    return 0


def prepare_scripts(config):
  """
  Will prepare script for slapos dedicated computer
  """
  dry_run = config.dry_run

  # Get slapos.cfg path
  if hasattr(config, 'slapos_configuration'):
    slapos_configuration = config.slapos_configuration
  else:
    # Check for config file in /etc/slapos/
    if os.path.exists('/etc/slapos/slapos.cfg'):
      slapos_configuration = '/etc/slapos/'
    else:
      slapos_configuration = '/etc/opt/slapos/'

  # Creating boot script
  path = os.path.join('/', 'usr', 'sbin', 'slapos-boot-dedicated')
  print "Creating %r" % path
  if not dry_run:
    open(path, 'w').write(
      pkg_resources.resource_stream(__name__,
                                    'script/%s' % 'slapos').read()
                                    % {'slapos_configuration': slapos_configuration})
    os.chmod(path, 0755)

  path = os.path.join('/', 'etc',
                      'systemd', 'system',
                      'slapos-boot-dedicated.service')
  print "Creating %r" % path
  if not dry_run:
    open(path, 'w').write(
      pkg_resources.resource_stream(__name__,
                                    'script/%s' % 'slapos.service').read()
      % dict(slapos_configuration=slapos_configuration))
    os.chmod(path, 0755)

  # add clientipv4
  path = os.path.join('/', 'etc', 'openvpn', 'clientipv4.conf')
  print "Creating %r" % path
  if not dry_run:
    open(path, 'w').write(
      pkg_resources.resource_stream(__name__,
                                    'template/%s' % 'clientipv4.conf.in').read())
    os.chmod(path, 0755)

  # Remove old-timers scripts
  remove_former_scripts(slapos_configuration)


def configureNtp():
  """Configures NTP daemon"""
  server = "server pool.ntp.org"
  old_ntp = open('/etc/ntp.conf', 'r').readlines()
  new_ntp = open('/etc/ntp.conf', 'w')
  for line in old_ntp:
    if line.startswith('server'):
      continue
    new_ntp.write(line)
  new_ntp.write(SLAPOS_MARK)
  new_ntp.write(server + '\n')
  new_ntp.close()
  _call(['chkconfig', '--add', 'ntp'])
  _call(['chkconfig', 'ntp', 'on'])
  _call(['systemctl', 'enable', 'ntp.service'])
  _call(['systemctl', 'restart', 'ntp.service'])


class Config:
  def setConfig(self, option_dict):
    """
    Set options given by parameters.
    """
    # Set options parameters
    for option, value in option_dict.__dict__.items():
      setattr(self, option, value)

  def slaposConfig(self,
                   mount_dir_path,
                   slapos_configuration,
                   hostname_path,
                   host_path, key_path,
                   master_url,
                   temp_dir,
                   computer_id):
    """
    Set configuration for slapos
    """
    self.slapos_configuration = slapos_configuration
    self.hostname_path = hostname_path
    self.host_path = host_path
    self.key_path = key_path
    self.master_url = master_url
    self.mount_dir_path = mount_dir_path
    self.temp_dir = temp_dir
    self.computer_id = computer_id

  def userConfig(self):
    # XXX-Testme: test each possible scenario
    # XXX don't use self.xx but return a dict so that it is stateless
    #     and easy to test
    # XXX rename "get_yes_no" so that we don't have insane cases like
    #     "if not get_yes_no('...')"
    already_configured = getSlaposConfiguration()
    self.certificates = get_yes_no("Automatically register new computer to a SlapOS Master?", True)
    if self.certificates:
      if already_configured:
        if not get_yes_no("A SlapOS Node configuration has been found. Do you want to overwrite it?", False):
          print "Okay, let's start from scratch."
          return False
      self.master_url = raw_input("""SlapOS Master URL? Empty answer will make it use slapos.org Master: """)
      if self.master_url:
        self.master_url_web = raw_input("""SlapOS Master "web" URL?: """)
      else:
        self.master_url_web = ''
      self.computer_name = raw_input("Define a unique name for this computer: ")
      self.partition_amount = raw_input("""Number of SlapOS partitions for this computer? Default is 20: """)
      if self.partition_amount == '':
        self.partition_amount = '20'
    elif not already_configured:
      print "No existing Node configuration has been found. please either automatically register or manually setup Node configuration."
      print "Starting from scratch..."
      return False

    self.one_disk = not get_yes_no("Do you want to use SlapOS with a second disk?", True)
    self.need_bridge = get_yes_no("Do you want the setup to allow virtual machines inside this node?", True)

    self.force_vpn = get_yes_no("Do you want to use vpn to provide ipv6?", True)
    self.force_slapcontainer = get_yes_no("Do you want to force the use lxc on this computer?", False)
    if self.force_vpn:
      self.ipv6_interface = "tapVPN"
    else:
      self.ipv6_interface = ""
    self.need_ssh = get_yes_no("Do you want to (re)configure remote SSH access?", True)

    return True

  def displayUserConfig(self):
    # XXX print everything from configuration, not arbitrary members
    if self.certificates:
      print "Will register a computer on master"
      if self.master_url:
        print "URL of master: %s" % self.master_url
        print "URL \"web\" of master: %s" % self.master_url_web
      print "Number of partition: %s" % (self.partition_amount)
      print "Computer name: %s" % self.computer_name
    print "Network bridge for hosted VMs: %s" % self.need_bridge
    print "Ipv6 over VPN: %s" % self.force_vpn
    print "Remote ssh access: %s" % self.need_ssh
    print "Prepared to use lxc: %s" % self.force_slapcontainer
    print "Use a second disk: %s" % (not self.one_disk)


def prepare_from_scratch(config):
  try:
    temp_directory = os.path.join('/tmp/slaptemp/')
    if not os.path.exists(temp_directory):
      print "Creating directory: %s" % temp_directory
      os.mkdir(temp_directory, 0711)

    while True:
      if config.userConfig():
        print "\nThis is your configuration: \n"
        config.displayUserConfig()
        if get_yes_no("\nDo you confirm?"):
          break

    if config.certificates:
      slapos_configuration = '/etc/opt/slapos/'
    else:
      # Check for config file in /etc/slapos/
      if os.path.exists('/etc/slapos/slapos.cfg'):
        slapos_configuration = '/etc/slapos/'
      else:
        slapos_configuration = '/etc/opt/slapos/'

    # Prepare Slapos Configuration
    if config.certificates:
      if config.force_vpn:
        print "Starting IPv6 tunnel..."
        _call(['systemctl', 'start', 'openvpn.service'])
        # XXX better way to check
        time.sleep(10)
      slapos_register_parameter_list = [
          'slapos', 'node', 'register', config.computer_name,
          '--interface-name', 'br0',
          '--ipv6-interface', config.ipv6_interface,
          '--partition-number', config.partition_amount
      ]
      if config.master_url:
        slapos_register_parameter_list.extend([
            '--master-url', config.master_url,
            '--master-url-web', config.master_url_web,
        ])
      _call(slapos_register_parameter_list)

    if getSlaposConfiguration():
      if config.need_bridge:
        setup_bridge(slapos_configuration, True)
      else:
        setup_bridge(slapos_configuration, False)
    else:
      print 'Warning: impossible to set up bridge because slapos configuration doesn\'t exist.'

    computer_id = get_computer_name(
        os.path.join('/', slapos_configuration, 'slapos.cfg'))

    print "Your Computer is : %s" % computer_id

    config.slaposConfig(mount_dir_path='/',
                        slapos_configuration=slapos_configuration,
                        hostname_path='/etc/HOSTNAME',
                        host_path='/etc/hosts',
                        key_path=os.path.join(temp_directory, 'authorized_keys'),
                        master_url="""https://slap.vifib.com""",
                        temp_dir=temp_directory,
                        computer_id=computer_id)

    # Prepare SlapOS Suse Server confuguration
    if config.need_ssh:
      get_ssh(temp_directory)

    slapserver(config)

    if not config.one_disk:
      _call(['/etc/init.d/slapos_firstboot'])
      _call(['zypper', '--gpg-auto-import-keys', 'install', '-fy', 'slapos.node'])
      _call(['systemctl', 'stop', 'slapos-node.service'])

    return_code = 0
  except ExecError as err:
    print >>sys.stderr, err.msg
    return_code = 16
  except SystemExit as err:
    # Catch exception raise by optparse
    return_code = err
  if os.path.exists(temp_directory):
    print "Deleting directory: %s" % temp_directory
    _call(['rm', '-rf', temp_directory])

  # Add/remove VPN file forcing/forbidding start of VPN.
  if not config.dry_run:
    openvpn_needed_file_path = os.path.join(slapos_configuration,
                                            'openvpn-needed')
    if config.force_vpn:
      # Force use of openvpn
      open(openvpn_needed_file_path, 'w')
    elif os.path.exists(openvpn_needed_file_path):
      # Forbid use of openvpn if not explicitely defined
      os.remove(openvpn_needed_file_path)

  return return_code


def chownSlaposDirectory():
  config = getSlaposConfiguration()

  slapos_slapgrid_instance = config.get('slapos', 'instance_root')
  slapos_slapgrid_software = config.get('slapos', 'software_root')
  slapformat_partition = config.get('slapformat', 'partition_amount')
  slapformat_partition_base_name = config.get('slapformat', 'partition_base_name')
  slapformat_user_base_name = config.get('slapformat', 'user_base_name')

  path = slapos_slapgrid_instance
  print "Changing owners of software directory and partitions directories…"
  for i in range(int(slapformat_partition)):
    uid = pwd.getpwnam('%s%s' % (slapformat_user_base_name, i))[2]
    gid = pwd.getpwnam('%s%s' % (slapformat_user_base_name, i))[3]
    item = '%s%s' % (slapformat_partition_base_name, i)
    if not os.path.islink(os.path.join(path, item)):
      os.chown(os.path.join(path, item), uid, gid)

  for i in range(int(slapformat_partition)):
   path = "%s/%s%s" % (slapos_slapgrid_instance, slapformat_partition_base_name, i)
   for root, dirs, files in os.walk(path):
    for items in dirs, files:
     for item in items:
       if not os.path.islink(os.path.join(root, item)):
         os.chown(os.path.join(root, item),
                  pwd.getpwnam('%s%s' % (slapformat_user_base_name, i))[2],
                  pwd.getpwnam('%s%s' % (slapformat_user_base_name, i))[3])

  # chown of software root (/opt/slapgrid)
  for root, dirs, files in os.walk(slapos_slapgrid_software):
    for items in dirs, files:
      for item in items:
        if not os.path.islink(os.path.join(root, item)):
          os.chown(os.path.join(root, item),
                   pwd.getpwnam('slapsoft')[2],
                   pwd.getpwnam('slapsoft')[3])


def slapprepare():
  """
  Prepare SlapOS dedicated computer
  """
  usage = "usage: %s [options] " % sys.argv[0]
  try:
    config = Config()
    config.setConfig(Parser(usage=usage).check_args())

    # Install/update slapos
    try:
      _call(['zypper', 'addrepo', '-fc', '-n', '"SlapOS Official repo"',
             'http://download.opensuse.org/repositories/home:/VIFIBnexedi/openSUSE_%s/' % suse_version(), 'slapos'])
    except:
      pass
    _call(['zypper', '--gpg-auto-import-keys', 'install', '-y', 'slapos.node'])
    _call(['systemctl', 'stop', 'slapos-node.service'])

    print "SlapOS has been updated"

    if not config.update:
      prepare_from_scratch(config)

    prepare_scripts(config)

    configureNtp()

    try:
      chownSlaposDirectory()
    except:
      print "Warning: Impossible to change owner of slapos directories."

    # Restart sysctl in case of new mount points in /var/log
    _call(['systemctl', 'restart', 'syslog.service'])

    # Enable and run slapos-boot-dedicated.service
    _call(['systemctl', 'enable', 'slapos-boot-dedicated.service'])
    _call(['systemctl', 'start', 'slapos-boot-dedicated.service'])

    return_code = 0
  except UsageError as err:
    print >>sys.stderr, err.msg
    print >>sys.stderr, "For help use --help"
    return_code = 16
  except ExecError as err:
    print >>sys.stderr, err.msg
    return_code = 16
  except SystemExit as err:
    # Catch exception raise by optparse
    return_code = err
  sys.exit(return_code)


def main():
    slapprepare()
