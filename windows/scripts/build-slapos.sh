#! /bin/bash
export PATH=/usr/local/bin:/usr/bin:$PATH

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
    (($?)) && echo "SlapOS bootstrap failed." && exit 1
fi

bin/buildout -v -N
(($?)) && echo "Buildout SlapOS failed." && exit 1

# apply patches
patch_file=/etc/slapos/patches/slapos-core-format.patch
if [[ -f $patch_file ]] ; then
    echo "Apply patch: $patch_file"
    (cd `ls -d $slapos_home/eggs/slapos.core-*-py2.7.egg` ; \
     patch -p1 < $patch_file)
    (cd  /etc/slapos/patches ; mv $patch_file{,.done})
fi
