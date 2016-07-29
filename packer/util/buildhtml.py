#!/usr/bin/python

html = """
<div>
"""
image_description_dict = {

  "output-debian8/packer-debian8.gz" : {
    "title": "Debian 8 blank image ",
    "description": "Debian Image without any configuration (qcow2, 64bits, nographics)."
   },
  "output-debian7/packer-debian7.gz" : {
    "title": "Debian 7 blank image ",
    "description": "Debian Image without any configuration (qcow2, 64bits, nographics)."
   },
  "output-ubuntu-14-04-server/packer-ubuntu-14-04-server.gz" : {
    "title": "Ubuntu Server 14.04 blank image ",
    "description": "Ubuntu Server 14.04 Image without any configuration (qcow2, 64bits, nographics)."
   },
  "output-ubuntu-15-04-server/packer-ubuntu-15-04-server.gz" : {
    "title": "Ubuntu Server 15.04 blank image ",
    "description": "Ubuntu Server 15.04 Image without any configuration (qcow2, 64bits, nographics)."
   },
  "output-centos72/packer-centos72.gz" : {
    "title": "CentOS 7.2 blank image ",
    "description": "CentOS 7.2 without any configuration (qcow2, 64bits, nographics)."
   },
  "output-centos67/packer-centos67.gz" : {
    "title": "CentOS 6.7 blank image ",
    "description": "CentOS 6.7 without any configuration (qcow2, 64bits, nographics)."
   },
  "output-debian8-testing-version/packer-debian8-testing-version.gz" : {
    "title": "Debian 8 Image for run automatic tests ",
    "description": "Test Debian 8 VM to run tests on boot (qcow2, 64bits, nographics)."
   },
  "output-debian7-testing-version/packer-debian7-testing-version.gz" : {
    "title": "Debian 7 Image for run automatic tests ",
    "description": "Test Debian 7 VM to run tests on boot (qcow2, 64bits, nographics)."
   },
  "output-ubuntu-15-04-server-testing-version/packer-ubuntu-15-04-server-testing-version.gz" : {
    "title": "Ubuntu Server 15.04 Image for run automatic tests ",
    "description": "Test Ubuntu Server 15.04 VM to run tests on boot (qcow2, 64bits, nographics)."
   },
  "output-ubuntu-14-04-server-testing-version/packer-ubuntu-14-04-server-testing-version.gz" : {
    "title": "Ubuntu Server 14.04 Image for run automatic tests ",
    "description": "Test Ubuntu Server 14.04 VM to run tests on boot (qcow2, 64bits, nographics)."
   },
  "output-centos67-testing-version/packer-centos67-testing-version.gz" : {
    "title": "CentOS 6.7 Image for run automatic tests ",
    "description": "Test CentOS 6.7 VM to run tests on boot (qcow2, 64bits, nographics)."
   },
  "output-centos72-testing-version/packer-centos72-testing-version.gz" : {
    "title": "CentOS 7.2 Image for run automatic tests ",
    "description": "Test CentOS 7.2 VM to run tests on boot (qcow2, 64bits, nographics)."
   },
  "output-debian8-webrunner/packer-debian8-webrunner.gz" : {
    "title": "Debian 8 Image with webrunner standalone inside ",
    "description": "Debian 8 VM with webrunner pre-setuped inside (qcow2, 64bits, nographics)."
   },
  "output-debian8-erp5-standalone/packer-debian8-erp5-standalone.gz" : {
    "title": "Debian 8 VM with ERP5 Standalone pre-installed inside",
    "description": "Debian 8 VM with ERP5 standalone pre-installed inside (qcow2, 64bits, nographics)."
   },
  "output-debian8-wendelin/packer-debian8-wendelin.gz" : {
    "title": "Debian 8 VM with Wendelin Standalone",
    "description": "Debian 8 instance with Wendelin Standalone "\
                   " pre-setuped inside (qcow2, 64bits, nographics). "
   },
  "output-debian8-vm-bootstrap/packer-debian8-vm-bootstrap.gz" : {
    "title": "Debian 8 VM with support to bootstrap script ",
    "description": "Debian 8 vm with support with bootstrap script,"\
                   " to be used only with KVM Cluster (qcow2, 64bits, nographics)."
   },
  "output-debian7-vm-bootstrap/packer-debian7-vm-bootstrap.gz" : {
    "title": "Debian 7 VM with support to bootstrap script ",
    "description": "Debian 7 vm with support with bootstrap script, "\
                   "to be used only with KVM Cluster. (qcow2, 64bits, nographics)."
   },
  "output-ubuntu-14-04-server-vm-bootstrap/packer-ubuntu-14-04-server-vm-bootstrap.gz" : {
    "title": "Ubuntu 14.04 VM with support to bootstrap script ",
    "description": "Ubuntu 14.04 VM with support with bootstrap script,"\
                   " to be used only with KVM Cluster (qcow2, 64bits, nographics)."
   },
  "output-ubuntu-15-04-server-vm-bootstrap/packer-ubuntu-15-04-server-vm-bootstrap.gz" : {
    "title": "Ubuntu 15.04 VM with support to bootstrap script ",
    "description": "Ubuntu 15.04 VM with support to bootstrap script, "\
                   " to be used only with KVM Cluster (qcow2, 64bits, nographics).."
   },
  "output-centos68-vm-bootstrap/packer-centos68-vm-bootstrap.gz" : {
    "title": "CentOS 6.8 VM with support to bootstrap script ",
    "description": "CentOS 6.8 VM with support to bootstrap script, "\
                   "to be used only with KVM Cluster. (qcow2, 64bits, nographics)"
   },
  "output-centos72-vm-bootstrap/packer-centos72-vm-bootstrap.gz" : {
    "title": "CentOS 7.2 VM with support to bootstrap script ",
    "description": "CentOS 7.2 VM with support to bootstrap script, "\
                   "to be used only with KVM Cluster (qcow2, 64bits, nographics)."
   },
}

for line in open("SHA512SUM.txt", "r"):
  sha, image_path = line[:-1].split("  ")
  print image_path
  html += """
  <h2> %s </h2>
  <p> Description: %s <br />
      Link to download: <a href=http://download.shacache.org/%s>Download</a> <br />
      SHA512SUM: %s 
  </p>
  <br />
  """ % (image_description_dict[image_path]['title'], 
         image_description_dict[image_path]['description'], 
         sha, sha)

html += """
</div>
"""
print(html)


