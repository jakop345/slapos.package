from _util import _call

SLAPOS_MARK = '# Added by SlapOS\n'

class Promise:

  def checkConsistency(self, fixit=0, **kw):
    is_ok = False
     
    if not is_ok and fixit:
      return self.fixConsistency(**kw)

    return is_ok

  def fixConsistency(self, **kw)
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
    return self.checkConsistency(fixit=0, **kw)
