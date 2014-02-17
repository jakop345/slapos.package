from slapos.package.base_promise import BasePackagePromise

class Promise(BasePackagePromise):
  package_name = "ntp"
  binary_path = '/usr/sbin/ntpd'
