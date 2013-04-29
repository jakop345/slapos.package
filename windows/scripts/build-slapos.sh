#! /bin/bash

if [[ ! -d /opt/slapos ]] ; then
    mkdir -p /opt/slapos
fi
if [[ ! -d /opt/download-cache ]] ; then
    mkdir -p /opt/download-cache
fi

cd /opt/slapos
if [[ ! -f buildout.cfg ]] ; then
    echo "[buildout]
extends = http://git.erp5.org/gitweb/slapos.git/blob_plain/refs/tags/cygwin-0:/component/slapos/buildout.cfg
download-cache = /opt/download-cache
prefix = ${buildout:directory}
" > buildout.cfg 
fi

if [[ ! -f bootstrap.py ]] ; then
    python -S -c 'import urllib2;print urllib2.urlopen("http://git.erp5.org/gitweb/slapos.core.git/blob_plain/HEAD:/bootstrap.py").read()' > bootstrap.py
    python -S bootstrap.py
fi

bin/buildout -v -N

if (( ! $? == 0 )) ; then
    echo "Error: buildout of slapos failed"
    exit 1
fi

# apply patches
if [[ -f /etc/slapos/patches/slapos-core.patch ]] ; then
    (cd `ls -d /opt/slapos/eggs/slapos.core-*-py2.7.egg`/slapos ; \
     patch -p1 < /etc/slapos/patches/slapos-core.patch )
    (cd  /etc/slapos/patches ; mv slapos-core.patch slapos-core.patch.done)
fi
