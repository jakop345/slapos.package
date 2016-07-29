SlapOS Image Generation with Packer
====================================

This tool repository of packer configuration files are used to generate 
VM Ready to use for SlapOS and as well containing VM Images with slapos
inside.

How to build one VM?
--------------------

1) Install Packer locally by https://www.packer.io/downloads.html, like (exemple):

::

  mkdir /opt/packer/
  cd /opt/packer/
  wget https://releases.hashicorp.com/packer/0.10.1/packer_0.10.1_linux_amd64.zip
  unzip packer_0.10.1_linux_amd64.zip

2) Building one VM (example)::
  
::
  PATH=$PATH:/opt/packer packer build debian8.json

3) You can watch qemu working on a linux machine (with X running), you just 
have to edit the json. Replace '"headless": true' by '"headless": false'

How to build all VMs?
---------------------

You can use ansible for build all VMs locally, and gzip them:

::

  ansible-playbook build.yml -i localhost,

How to upload to shacache?
--------------------------

For upload the images to shacache you can run an ansible command, however,
you need to place your shacache keys and certificates at shacache folder, and
eventually, update shacache/shacache.cfg.

BE CAREFULL, every time you run this command you upload the files to shacache,
even if the files are there already.

::

  ansible-playbook upload.yml -i localhost,
 
How can I check if all images are on shacache?
----------------------------------------------

You can use the script 'util/testupload.sh' to know if all generated images 
are uploaded to shacache.

::

  bash util/testupload.sh
  # expected output similat to this
  OK 7d3f421e75ca114abcc20b4bed6cb6fc3d430b8c016b00a1d9cb1f14af6f3c342de6a5dd3c42b52de6f49cc5800bff7879884466edba1f6fef8623bb7448832c
  OK a0247996af937d9b1ce86cac570b98b629c05c62860c8fd88d922171c141ea6a94a1d2122ba131bdcfa712712b4674be8e332940ade7adccee55a7de7bda0d18


How to download one image from shacache?
----------------------------------------

The images are downloaded by the SHA512SUM hash of it. Example:

::

  sha512sum output-centos72/packer-centos72.gz
  a0247991d2122ba131b...BIGHASH...fa712712b4674be8e332940ade7adccee55a7de7bda0d18 output-centos72/packer-centos72.gz
  wget http://download.shacache.org/a0247991d2122ba131b...BIGHASH...fa712712b4674be8e332940ade7adccee55a7de7bda0d18
  # if you want a good filename use '-O centos.gz'
  # them you can gunzip
  gunzip centos.gz

How to run locally a downloaded image?
--------------------------------------

In order to test one image (after unzip), you can run:

::

  bash util/quick-test IMAGE.qcow2
  # or if you want use X and a monitor you can do:
  bash util/quick-test packer-centos72 "-display sdl"


Extra
-----

The automated test suite is been developed, so until now, those VMs are 
considered unstable not recommended for production.

