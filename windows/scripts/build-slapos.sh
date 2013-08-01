#! /bin/bash
export PATH=/usr/local/bin:/usr/bin:/usr/sbin:/sbin:/bin:$PATH

function show_error_exit()
{
    echo Error: ${1:-"build slapos failed."}
    read -n 1 -p "Press any key to exit..."
    exit 1
}

slapos_home=${1:-/opt/slapos}
slapos_cache=/opt/download-cache
slapos_url=http://git.erp5.org/gitweb/slapos.git/blob_plain/refs/heads/cygwin-0:/component/slapos/buildout.cfg
slapos_cfg=$slapos_home/buildout.cfg
slapos_bootstrap=$slapos_home/bootstrap.py
patch_files=/etc/slapos/patches/slapos-core-format.patch

mkdir -p $slapos_home/log
mkdir -p $slapos_cache

echo "Checking $slapos_cfg ..."
if [[ -r $slapos_cfg ]] ; then
    echo "Change $slapos_cfg:"
    echo "  extends = ${slapos_url}"
    sed -i -e "s%^extends = .*$%extends = ${slapos_url}%g" $slapos_cfg
else
    cat <<EOF  > $slapos_cfg
[buildout]
extends = ${slapos_url}
download-cache = ${slapos_cache}
prefix = $${buildout:directory}
EOF
    echo "File $slapos_cfg has been generated."
fi

echo "Checking $slapos_bootstrap ..."
if [[ ! -f $slapos_bootstrap ]] ; then
    echo "Downloading $slapos_bootstrap ..."
    python -S -c 'import urllib2;print urllib2.urlopen("http://git.erp5.org/gitweb/slapos.core.git/blob_plain/HEAD:/bootstrap.py").read()' > $slapos_bootstrap ||
    show_error_exit "Error: download $slapos_bootstrap"
    echo "Downlaod $slapos_bootstrap OK."
else
    echo OK.
fi

if [[ ! -x $slapos_home/run/buildout ]] ; then
    echo "Bootstrap slapos ..."
    (cd $slapos_home ; python -S bootstrap.py) || show_error_exit "Error: slapos bootstrap failed."
    echo "Bootstrap slapos OK."
fi

echo
echo Start buildout of slapos ...
echo
(cd $slapos_home ; $slapos_home/bin/buildout -v -N) || show_error_exit "Error slapos buildout failed."

# apply patches
for _filename in $patch_files ; do
    if [[ -r ${_filename} ]] ; then
        echo "Apply patch: ${_filename}"
        for _path in $(find $slapos_home/eggs -name slapos.core-*.egg) ; do
            echo "  at ${_path} ..."
            (cd ${_path} ; patch -f --dry-run -p1 < ${_filename} > /dev/null &&
                patch -p1 < ${_filename} && echo "OK.")
        done
    fi
done

echo
echo Build slapos node successfully.
echo
read -n 1 -t 60 -p "Press any key to exit..."
exit 0
