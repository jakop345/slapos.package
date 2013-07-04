#! /bin/bash
export PATH=/usr/local/bin:/usr/bin:/usr/sbin:/sbin:/bin:$PATH

slapos_home=${1-/opt/slapos}
slapos_cache=/opt/download-cache
slapos_url=http://git.erp5.org/gitweb/slapos.git/blob_plain/refs/heads/cygwin-0:/component/slapos/buildout.cfg
slapos_cfg=$slapos_home/buildout.cfg
slapos_bootstrap=$slapos_home/bootstrap.py
patch_files=/etc/slapos/patches/slapos-core-format.patch

mkdir -p $slapos_home/log
mkdir -p $slapos_cache

if [[ -r $slapos_cfg ]] ; then
    echo "Change $slapos_home/buildout.cfg with "
    echo "  extends = ${slapos_url}"
    sed -i -e "s%^extends = .*$%extends = ${slapos_url}%g" $slapos_cfg
else
    cat <<EOF  > $slapos_cfg
[buildout]
extends = ${slapos_url}
download-cache = ${slapos_cache}
prefix = $${buildout:directory}
EOF
    echo "$slapos_home/buildout.cfg created."
fi

if [[ ! -f $slapos_bootstrap ]] ; then
    python -S -c 'import urllib2;print urllib2.urlopen("http://git.erp5.org/gitweb/slapos.core.git/blob_plain/HEAD:/bootstrap.py").read()' > $slapos_bootstrap
    echo "$slapos_bootstrap downloaded."
    if (! cd $slapos_home ; python -S bootstrap.py) ; then
        echo "SlapOS bootstrap failed."
        exit 1
    fi
fi

# cd $slapos_home
if (! cd $slapos_home ; $slapos_home/bin/buildout -v -N) ; then
    echo "SlapOS buildout failed."
    exit 1
fi

# apply patches
for filename in $patch_files ; do
    if [[ -r $filename ]] ; then
        echo "Apply patch: $filename"
        for x in $(find $slapos_home/eggs -name slapos.core-*.egg) ; do
            echo "  at $x ..."
            (cd $x ; patch -f --dry-run -p1 < $filename > /dev/null && \
                patch -p1 < $filename && echo "  OK.")
        done
    fi
done

echo Build SlapOS successfully.
read -n 1 -t 60 -p "Press any key to exit..."
exit 0
