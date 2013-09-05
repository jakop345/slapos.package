#! /bin/bash
#
# This script is used to build slapos node from source.
#
export PATH=/usr/local/bin:/usr/bin:/usr/sbin:/sbin:/bin:$PATH
if ! source /usr/share/csih/cygwin-service-installation-helper.sh ; then
    echo "Error: Missing csih package."
    exit 1
fi

# ======================================================================
# Functions
# ======================================================================
function slapos_apply_patch()
{
    local _filename=$1
    local _destpath=$2
    local _basename=$(basename ${_filename})

    [[ -f ${_filename} ]] ||
    cp /opt/git/slapos.package/windows/patches/${_basename} ${_filename} 2>/dev/null ||
    wget -c http://git.erp5.org/gitweb/slapos.package.git/blob_plain/heads/cygwin:/windows/patches/${_basename} -O ${_filename} ||
    csih_error "download ${_filename} failed"
    csih_inform "download ${_filename} OK"

    csih_inform "applay patch ${_filename}"
    (cd $(ls -d ${_destpath}) &&
        csih_inform "patch at $(pwd)" &&
        patch -f --dry-run -p1 < ${_filename} > /dev/null &&
        patch -p1 < ${_filename} &&
        csih_inform "apply patch ${_filename} OK")
}
readonly -f slapos_apply_patch

function slapos_buildout()
{
    local _home=$1/slapos
    local _cache=$1/download-cache
    local _buildcfg=${_home}/buildout.cfg
    local _bootstrap=${_home}/bootstrap.py
    local _buildurl=${2:-http://git.erp5.org/gitweb/slapos.git/blob_plain/refs/heads/cygwin-share:/component/slapos/buildout.cfg}

    [[ -z "$1" ]] && csih_error "no slapos path specified"

    csih_inform "Starting run buildout of slapos node ..."

    csih_inform "mkdir ${_home}/log"
    mkdir -p ${_home}/log 

    csih_inform "mkdir ${_cache}"
    mkdir -p ${_cache}

    [[ ! -f ${_buildcfg} ]] &&
    echo "[buildout]
extends = ${_buildurl}
download-cache = ${_cache}
prefix = \${buildout:directory}
" > ${_buildcfg} &&
    csih_inform "${_buildcfg} generated"

    [[ -f ${_bootstrap} ]] ||
    python -S -c 'import urllib2;print urllib2.urlopen("http://git.erp5.org/gitweb/slapos.core.git/blob_plain/HEAD:/bootstrap.py").read()' > ${_bootstrap} ||
    csih_error "download bootstrap.py failed"
    csih_inform "download ${_bootstrap} OK"

    [[ -x ${_home}/bin/buildout ]] ||
    (cd ${_home} && python -S bootstrap.py) ||
    csih_error "run bootstrap.py failed"
    csih_inform  "run bootstrap.py OK"

    csih_inform "start bin/buildout"
    (cd ${_home} ; bin/buildout -v -N) || csih_error "bin/buildout failed"

    slapos_apply_patch "~/slapos-core-format.patch" "${_home}/eggs/slapos.core-*.egg/"
    slapos_apply_patch "~/supervisor-cygwin.patch" "${_home}/eggs/supervisor-*.egg/"

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
declare -r slapos_path=${1:-/opt}

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
slapos_buildout ${slapos_path}

# -----------------------------------------------------------
# End script
# -----------------------------------------------------------
echo ""
csih_inform "Build slapos successfully."
echo ""

read -n 1 -t 60 -p "Press any key to exit..."
exit 0
