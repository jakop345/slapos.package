#! /bin/bash

slapos_home=/opt/slapos
slapos_cache=/opt/download-cache

if [[ ! -d $slapos_home ]] ; then
    echo "Make directory of slapos home: $slapos_home"
    mkdir -p $slapos_home
fi
if [[ ! -d $slapos_cache ]] ; then
    echo "Make directory of slapos cache: $slapos_cache"
    mkdir -p $slapos_cache
fi

cd $slapos_home
if [[ ! -f buildout.cfg ]] ; then
    echo "Create $slapos_home/buildout.cfg"
    echo "[buildout]
extends = http://git.erp5.org/gitweb/slapos.git/blob_plain/refs/heads/cygwin-0:/component/slapos/buildout.cfg
download-cache = /opt/download-cache
prefix = ${buildout:directory}
" > buildout.cfg 
fi

if [[ ! -f bootstrap.py ]] ; then
    echo "Download $slapos_home/bootstrap.py"
    python -S -c 'import urllib2;print urllib2.urlopen("http://git.erp5.org/gitweb/slapos.core.git/blob_plain/HEAD:/bootstrap.py").read()' > bootstrap.py
    python -S bootstrap.py
fi

bin/buildout -v -N || (echo "Buildout SlapOS failed."; exit 1)

# apply patches
if [[ -f /etc/slapos/patches/slapos-core.patch ]] ; then
    echo "Apply patch: /etc/slapos/patches/slapos-core.patch"
    (cd `ls -d $slapos_home/eggs/slapos.core-*-py2.7.egg`/slapos ; \
     patch -p1 < /etc/slapos/patches/slapos-core.patch )
    (cd  /etc/slapos/patches ; mv slapos-core.patch slapos-core.patch.done)
fi
