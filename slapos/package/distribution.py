import platform
import glob
import re
import os

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

  def matchSignatureList(self, signature_list):
    return self.getOSSignature() in signature_list

  def getOSSignature(self):
    return "+++".join(patched_linux_distribution())

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

  def _installSoftwareList(self, name_list):
    """ Upgrade softwares """
    return self._getDistribitionHandler().installSoftwareList(self._call, name_list)

  def _updateSoftware(self):
    """ Upgrade softwares """
    return self._getDistribitionHandler().updateSoftware(self._call)

  def _updateSystem(self):
    """ Dist-Upgrade of system """
    return self._getDistribitionHandler().updateSystem(self._call)

  def update(self, repository_list=[], package_list=[]):
    """ Perform upgrade """
    self._purgeRepository()
    for alias, url in repository_list:
      self._addRepository(url, alias)
    self._updateRepository()
    if len(package_list):
      self._installSoftwareList(package_list)

# This helper implements API for package handling
class AptGet:
 
  source_list_path = "/etc/apt/sources.list"
  source_list_d_path = "/etc/apt/sources.list.d"

  def purgeRepository(self, caller):
    """ Remove all repositories """
    # Aggressive removal
    os.remove(self.source_list_path)
    open("/etc/apt/sources.list", "w+").write("# Removed all")
    for file_path in glob.glob("%s/*" % self.source_list_d_path):
      os.remove(file_path)

  def addRepository(self, caller, url, alias):
    """ Add a repository """
    repos_file = open("%s/%s.list" % (self.source_list_d_path, alias), "w")
    prefix = "deb "
    if alias.endswith("-src"):
      prefix = "deb-src "
    repos_file.write(prefix + url)
    repos_file.close()

  def updateRepository(self, caller):
    """ Add a repository """
    caller(['apt-get', 'update'], stdout=None)

  def installSoftwareList(self, caller, name_list):
    """ Instal Software """
    self.updateRepository(caller)
    command_list = ["apt-get", "install", "-y"]
    command_list.extend(name_list)
    caller(command_list, stdout=None) 

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

  def installSoftwareList(self, caller, name_list):
    """ Instal Software """
    self.updateRepository(caller)
    command_list = ['zypper', '--gpg-auto-import-keys', 'up', '-ly']
    command_list.extend(name_list)
    caller(command_list, stdout=None) 

  def updateSoftware(self, caller):
    """ Upgrade softwares """
    caller(['zypper', '--gpg-auto-import-keys', 'up', '-ly'], stdout=None)

  def updateSystem(self, caller):
    """ Dist-Upgrade of system """
    caller(['zypper', '--gpg-auto-import-keys', 'dup', '-ly'], stdout=None)


def do_discover():
  package_manager = PackageManager()
  print package_manager.getOSSignature()


