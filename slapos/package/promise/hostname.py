from slapos.package.base_promise import BasePromise
import os

class Promise(BasePromise):

  configuration_file_path = '/etc/HOSTNAME' 

  def checkConsistency(self, fixit=0, **kw):
    is_ok = False
    computer_id = kw["computer_id"]

    self.log("Setting hostname in : %s" % self.configuration_file_path)
    if os.path.exists(self.configuration_file_path):
       is_ok = computer_id in open(self.configuration_file_path, 'r').read()

    if not is_ok and fixit:
      return self.fixConsistency(**kw)

    return is_ok

  def fixConsistency(self, **kw):
    """Configures hostname daemon"""
    computer_id = kw["computer_id"]
    open(self.configuration_file_path, 'w').write("%s\n" % computer_id)
    self._call(['hostname', '-F', self.configuration_file_path])
    return self.checkConsistency(fixit=0, **kw)
