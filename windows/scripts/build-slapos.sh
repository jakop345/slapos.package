#! /bin/bash
#
# This script is used to build slapos node from source.
#
export PATH=/usr/local/bin:/usr/bin:/usr/sbin:/sbin:/bin:$PATH
if ! source /usr/share/csih/cygwin-service-installation-helper.sh ; then
    echo "Error: Missing csih package."
    exit 1
fi

function show_usage()
{
    echo "This script is used to build slapos node in the Cygwin."
    echo ""
    echo "Usage: ./build-slapos.sh"
    echo ""
}
readonly -f show_usage

function slapos_buildout()
{
    # -----------------------------------------------------------
    # Run the buildout of slapos node
    # -----------------------------------------------------------
    csih_inform "Starting run buildout of slapos node ..."

    csih_inform "mkdir /opt/slapos/log"
    mkdir -p ${slapos_home}/log

    csih_inform "mkdir /opt/download-cache"
    mkdir -p ${slapos_cache}

    [[ ! -f ${slapos_cfg} ]] &&
    echo "[buildout]
extends = ${slapos_url}
download-cache = ${slapos_cache}
prefix = ${buildout:directory}
" > ${slapos_cfg} &&
    csih_inform "${slapos_cfg} generated"

    [[ -f ${slapos_bootstrap} ]] ||
    python -S -c 'import urllib2;print urllib2.urlopen("http://git.erp5.org/gitweb/slapos.core.git/blob_plain/HEAD:/bootstrap.py").read()' > ${slapos_bootstrap} ||
    csih_error "download bootstrap.py failed"
    csih_inform "download ${slapos_bootstrap} OK"

    [[ -x ${slapos_home}/bin/buildout ]] ||
    (cd ${slapos_home} && python -S bootstrap.py) ||
    csih_error "run bootstrap.py failed"
    csih_inform  "run bootstrap.py OK"

    csih_inform "start bin/buildout"
    (cd ${slapos_home} ; bin/buildout -v -N) || csih_error "bin/buildout failed"

    _filename=~/slapos-core-format.patch
    [[ -f ${_filename} ]] ||
    wget -c http://git.erp5.org/gitweb/slapos.package.git/blob_plain/heads/cygwin:/windows/patches/$(basename ${_filename}) -O ${_filename} ||
    csih_error "download ${_filename} failed"
    csih_inform "download ${_filename} OK"

    csih_inform "applay patch ${_filename}"
    (cd $(ls -d ${slapos_home}/eggs/slapos.core-*.egg/) &&
        csih_inform "patch at $(pwd)" &&
        patch -f --dry-run -p1 < ${_filename} > /dev/null &&
        patch -p1 < ${_filename} &&
        csih_inform "apply patch ${_filename} OK")

    _filename=~/supervisor-cygwin.patch
    [[ -f ${_filename} ]] ||
    wget -c http://git.erp5.org/gitweb/slapos.package.git/blob_plain/heads/cygwin:/windows/patches/$(basename ${_filename}) -O ${_filename} ||
    csih_error "download ${_filename} failed"
    csih_inform "download ${_filename} OK"

    csih_inform "applay patch ${_filename}"
    (cd $(ls -d ${slapos_home}/eggs/supervisor-*.egg) &&
        csih_inform "patch at $(pwd)" &&
        patch -f --dry-run -p1 < ${_filename} > /dev/null &&
        patch -p1 < ${_filename} &&
        csih_inform "apply patch ${_filename} OK")

    csih_inform "Run buildout of slapos node OK"
    echo ""
}
readonly -f slapos_buildout

# -----------------------------------------------------------
# Start script
# -----------------------------------------------------------
csih_inform "Start slapos node configure ..."
echo ""

# -----------------------------------------------------------
# Local variable
# -----------------------------------------------------------
declare -r slapos_home=/opt/slapos
declare -r slapos_cache=/opt/download-cache
declare -r slapos_url=http://git.erp5.org/gitweb/slapos.git/blob_plain/refs/heads/cygwin-share:/component/slapos/buildout.cfg
declare -r slapos_cfg=${slapos_home}/buildout.cfg
declare -r slapos_bootstrap=${slapos_home}/bootstrap.py

# -----------------------------------------------------------
# Command line options
# -----------------------------------------------------------
while test $# -gt 0; do
    # Normalize the prefix.
    case "$1" in
    -*=*) optarg=`echo "$1" | sed 's/[-_a-zA-Z0-9]*=//'` ;;
    *) optarg= ;;
    esac

    case "$1" in
    -h | --help)
    show_usage
    exit 0
    ;;
    *)
    show_usage
    exit 1
    ;;
    esac

    # Next please.
    shift
done

# -----------------------------------------------------------
# Build SlapOS
# -----------------------------------------------------------
slapos_buildout

# -----------------------------------------------------------
# End script
# -----------------------------------------------------------
echo ""
csih_inform "Build slapos successfully."
echo ""

read -n 1 -t 60 -p "Press any key to exit..."
exit 0
