from slapos.package.base_promise import BasePromise

SLAPOS_MARK = '# Added by SlapOS\n'

class Promise(BasePromise):

  configuration_file_path = '/etc/ntp.conf'

  def checkConsistency(self, fixit=0, **kw):
    is_ok = False
    server = "server pool.ntp.org"
    old_ntp = open(self.configuration_file_path, 'r').readlines()
    for line in old_ntp:
      if line.startswith('server pool.ntp.org'):
        continue
        is_ok = True
    
    if not is_ok and fixit:
      return self.fixConsistency(**kw)

    return is_ok

  def fixConsistency(self, **kw)
    """Configures NTP daemon"""
    server = "server pool.ntp.org"
    old_ntp = open(self.configuration_file_path, 'r').readlines()
    new_ntp = open(self.configuration_file_path, 'w')
    for line in old_ntp:
      if line.startswith('server'):
        continue
      new_ntp.write(line)
    new_ntp.write(SLAPOS_MARK)
    new_ntp.write(server + '\n')
    new_ntp.close()
    self._chkconfig('ntp', 'add')
    self._chkconfig('ntp', 'on')
    self._service('ntp.service', 'enable')
    self._service['ntp.service', 'restart')
    return self.checkConsistency(fixit=0, **kw)

