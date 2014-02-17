import platform
import re

_distributor_id_file_re = re.compile("(?:DISTRIB_ID\s*=)\s*(.*)", re.I)
_release_file_re = re.compile("(?:DISTRIB_RELEASE\s*=)\s*(.*)", re.I)
_codename_file_re = re.compile("(?:DISTRIB_CODENAME\s*=)\s*(.*)", re.I)

def patched_linux_distribution(distname='', version='', id='',
                               supported_dists=platform._supported_dists,
                               full_distribution_name=1):
    # check for the Debian/Ubuntu /etc/lsb-release file first, needed so
    # that the distribution doesn't get identified as Debian.
    try:
        etclsbrel = open("/etc/lsb-release", "rU")
        for line in etclsbrel:
            m = _distributor_id_file_re.search(line)
            if m:
                _u_distname = m.group(1).strip()
            m = _release_file_re.search(line)
            if m:
                _u_version = m.group(1).strip()
            m = _codename_file_re.search(line)
            if m:
                _u_id = m.group(1).strip()
        if _u_distname and _u_version:
            return (_u_distname, _u_version, _u_id)
    except (EnvironmentError, UnboundLocalError):
            pass

    return platform.linux_distribution(distname, version, id, supported_dists, full_distribution_name)

class PackageManager:
  def getDistributionName(self):
    return patched_linux_distribution()[0]

  def getVersion(self):
    return patched_linux_distribution()[1]

  def _call(self, *args, **kw):
    """ This is implemented in BasePromise """
    raise NotImplemented

  def _getDistribitionHandler(self):
    distribution_name = self.getDistributionName()
    if distribution_name.lower() == 'opensuse':
      return Zypper()

    elif distribution_name.lower() in ['debian', 'ubuntu']:
      return AptGet()

    raise NotImplemented("Distribution (%s) is not Supported!" % distribution_name) 

  def _purgeRepository(self):
    """ Remove all repositories """
    return self._getDistribitionHandler().purgeRepository(self._call)

  def _addRepository(self, url, alias):
    """ Add a repository """
    return self._getDistribitionHandler().addRepository(self._call, url, alias)

  def _updateRepository(self):
    """ Add a repository """
    return self._getDistribitionHandler().updateRepository(self._call)

  def _installSoftware(self, name):
    """ Upgrade softwares """
    return self._getDistribitionHandler().installSoftware(self._call, name)

  def _updateSoftware(self):
    """ Upgrade softwares """
    return self._getDistribitionHandler().updateSoftware(self._call)

  def updateSystem(self):
    """ Dist-Upgrade of system """
    return self._getDistribitionHandler().updateSystem(self._call)

# This helper implements API for package handling
class AptGet:
  def purgeRepository(self, caller):
    """ Remove all repositories """
    raise NotImplemented

  def addRepository(self, caller, url, alias):
    """ Add a repository """
    raise NotImplemented

  def updateRepository(self, caller):
    """ Add a repository """
    caller(['apt-get', 'update'], stdout=None)

  def installSoftware(self, caller, name):
    """ Instal Software """
    self.updateRepository(caller)
    caller(["apt-get", "install", "-y", name], stdout=None) 

  def isUpgradable(self, caller, name):
    output, err = caller(["apt-get", "upgrade", "--dry-run"])
    for line in output.splitlines():
      if line.startswith("Inst %s" % name):
        return True
    return False

  def updateSoftware(self, caller):
    """ Upgrade softwares """
    self.updateRepository(caller)
    caller(["apt-get", "upgrade"], stdout=None) 

  def updateSystem(self, caller):
    """ Dist-Upgrade of system """
    caller(['apt-get', 'dist-upgrade', '-y'], stdout=None)

class Zypper:
  def purgeRepository(self, caller):
    """Remove all repositories"""
    listing, err = caller(['zypper', 'lr'])
    while listing.count('\n') > 2:
      output, err = caller(['zypper', 'rr', '1'], stdout=None)
      listing, err = caller(['zypper', 'lr'])

  def addRepository(self, caller, url, alias):
    """ Add a repository """
    output, err = caller(['zypper', 'ar', '-fc', url, alias], stdout=None)

  def updateRepository(self, caller):
    """ Add a repository """
    caller(['zypper', '--gpg-auto-import-keys', 'up', '-Dly'], stdout=None)

  def isUpgradable(self, caller, name):
    output, err = caller(['zypper', '--gpg-auto-import-keys', 'up', '-ly'])
    for line in output.splitlines():
      if line.startswith("'%s' is already installed." % name):
        return False
    return True

  def installSoftware(self, caller, name):
    """ Instal Software """
    self.updateRepository(caller)
    caller(['zypper', '--gpg-auto-import-keys', 'up', '-ly', name], stdout=None) 

  def updateSoftware(self, caller):
    """ Upgrade softwares """
    caller(['zypper', '--gpg-auto-import-keys', 'up', '-ly'], stdout=None)

  def updateSystem(self, caller):
    """ Dist-Upgrade of system """
    caller(['zypper', '--gpg-auto-import-keys', 'dup', '-ly'], stdout=None)

