#! /bin/bash
#
export PATH=/usr/local/bin:/usr/bin:/usr/sbin:/sbin:/bin:$PATH
if ! source /usr/share/csih/cygwin-service-installation-helper.sh ; then
    echo "Error: Missing csih package."
    exit 1
fi

# ======================================================================
# Functions
# ======================================================================
function show_usage()
{
    echo "This script is used to build a bootstrap slapos in cywin."
    echo ""
    echo "Usage:"
    echo ""
    echo "  ./slapos-cygwin-bootstrap.sh [--prefix=prefix] [-f | --force]"
    echo ""
    echo "      --prefix=prefix    The prefix is used by network connection name,"
    echo "                         cygwin service name."
    echo "      --force"
    echo "      -f                 Force mode, everything will be reinstalled "
    echo "                         even if it exits."
    echo ""
    echo "Before run this script, type the following command in the windows"
    echo "command console to install cygwin:"
    echo ""
    echo "  setup_cygwin.bat C:\slapos network"
    echo ""
}
readonly -f show_usage

function check_os_is_wow64()
{
  [[ $(uname) == CYGWIN_NT-*-WOW64 ]]
}
readonly -f check_os_is_wow64

function slapos_sanity_check()
{
    csih_check_program_or_error /usr/bin/cygport cygport
    csih_check_program_or_error /usr/bin/libtool libtool

    _filename=$(cygpath -a -w $(cygpath -w /)\\..\\setup.exe)
    [[ -f $(cygpath -u ${_filename}) ]] || csih_error "missing ${_filename}"
}
readonly -f slapos_sanity_check

function slapos_patch_cygwin()
{
    csih_inform "Patching cygwin packages for building slapos"

    csih_inform "libtool patched"
    sed -i -e "s/4\.3\.4/4.5.3/g" /usr/bin/libtool

    csih_inform "/etc/passwd generated"
    [[ -f /etc/passwd ]] || mkpasswd > /etc/passwd

    csih_inform "/etc/group generated"
    [[ -f /etc/group ]] || mkgroup > /etc/group

    _filename=/usr/bin/cygport
    if [[ -f ${_filename} ]] ; then
        csih_inform "Patching ${_filename} ..."
        sed -i -e 's/D="${workdir}\/inst"/D="${CYGCONF_PREFIX-${workdir}\/inst}"/g' ${_filename} &&
        csih_inform "OK"
    else
        csih_error "Missing cygport package, no ${_filename} found."
    fi
    _filename=/usr/share/cygport/cygclass/autotools.cygclass
    if [[ -f ${_filename} ]] ; then
        csih_inform "Patching ${_filename} ..."
        sed -i -e 's/prefix=$(__host_prefix)/prefix=${CYGCONF_PREFIX-$(__host_prefix)}/g' ${_filename} &&
        csih_inform "OK"
    else
        csih_error "Missing cygport package, no ${_filename} found."
    fi
    _filename=/usr/share/cygport/cygclass/cmake.cygclass
    if [[ -f ${_filename} ]] ; then
        csih_inform "Patching ${_filename} ..."
        sed -i -e 's/-DCMAKE_INSTALL_PREFIX=$(__host_prefix)/-DCMAKE_INSTALL_PREFIX=${CYGCONF_PREFIX-$(__host_prefix)}/g' ${_filename} &&
        csih_inform "OK"
    else
        csih_error "Missing cygport package, no ${_filename} found."
    fi

    # Change format of readme.txt
    _filename=$(cygpath -u $(cygpath -m /)/../readme.txt)
    if [[ -f ${_filename} ]] ; then
        echo "Changing $(cygpath -w ${_filename}) as dos format ..."
        unix2dos ${_filename} && echo OK.
    fi

    _filename=".minttyrc"
    echo Checking  ${_filename} ...
    if [[ ! -f ${_filename} || "${_install_mode}" == "force" ]] ; then
        cat <<EOF > ${_filename}
BoldAsFont=no
Font=Courier New
FontHeight=16
Scrollbar=none
EOF
        echo "${_filename} has been generated."
    else
        echo OK.
    fi

    _filename="/cygtty.bat"
    echo Checking  ${_filename} ...
    if [[ ! -x ${_filename} || "${_install_mode}" == "force" ]] ; then
        cat <<EOF > ${_filename}
@echo off

${slapos_cygroot:0:2}
chdir ${slapos_cygroot}\\bin

start mintty.exe -i /Cygwin-Terminal.ico -
EOF
        chmod +x ${_filename}
        echo "${_filename} has been generated."
    else
        echo OK.
    fi

    _filename="/autorebase.bat"
    echo Checking  ${_filename} ...
    if [[ ! -f ${_filename} || "${_install_mode}" == "force" ]] ; then
        cat <<EOF > ${_filename}
@echo off
${slapos_cygroot:0:2}
CHDIR ${slapos_cygroot}
${slapos_cygroot}\bin\find /opt/slapos -name "*.dll" > ${slapos_cygroot}\myfile.list
IF EXIST ${slapos_cygroot}\opt\slapgrid. ${slapos_cygroot}\bin\find /opt/slapgrid -name "*.dll" >> ${slapos_cygroot}\myfile.list
IF EXIST ${slapos_cygroot}\srv\slapgrid. ${slapos_cygroot}\bin\find /srv/slapgrid -name "*.dll" >> ${slapos_cygroot}\myfile.list
NET STOP ${slapos_prefix}cron
NET STOP ${slapos_prefix}re6stnet
NET STOP ${slapos_prefix}syslog-ng
NET STOP ${slapos_prefix}cygserver
bin\bash --login -c "/opt/slapos/bin/slapos node stop all"
bin\bash --login -c "for pid in \$(ps | grep '/usr/bin/python2.7' | gawk '{print \$4}') ; do TASKKILL /F /T /PID \$pid ; done"
PATH .\bin;%PATH%
dash /bin/rebaseall -T /myfile.list -v
PAUSE ...
EXIT 0
EOF
        chmod +x ${_filename}
        echo "${_filename} has been generated."
    else
        echo OK.
    fi

    csih_inform "Patch cygwin packages for building slapos OK"
    echo ""
}
readonly -f slapos_patch_cygwin

function install_slapos_cygwin_package()
{
    for _cmdname in ip useradd usermod groupadd brctl tunctl ; do
        [[ -f /usr/bin${_cmdname} && -z "${_install_mode}" ]] && continue
        wget -c http://git.erp5.org/gitweb/slapos.package.git/blob_plain/heads/cygwin:/windows/scripts/${_cmdname} -O /usr/bin/${_cmdname} ||
        csih_error "download ${_cmdname} failed"
        csih_inform "download cygwin script ${_cmdname} OK"
        chmod +x /usr/bin/${_cmdname} || csih_error "chmod /usr/bin/${_cmdname} failed"
    done

    for _cmdname in regpwd ; do
        [[ -x /usr/bin${_cmdname} && -z "${_install_mode}" ]] && continue
        wget -c http://dashingsoft.com/products/slapos/${_cmdname}.exe -O /usr/bin/${_cmdname}.exe ||
        csih_error "download ${_filename} failed"
        csih_inform "download ${_filename} OK"
        chmod +x /usr/bin/${_cmdname}.exe || csih_error "chmod /usr/bin/${_cmdname}.exe failed"
    fi

    for _cmdname in ipwin ; do
        [[ -x /usr/bin${_cmdname} && -z "${_install_mode}" ]] && continue
        if check_os_is_wow64 ; then
            _filename=${_cmdname}-x64.exe
        else
            _filename=${_cmdname}-x86.exe
        fi
        wget -c http://dashingsoft.com/products/slapos/${_filename} -O /usr/bin/${_cmdname}.exe ||
        csih_error "download ${_filename} failed"
        csih_inform "download ${_filename} OK"
        chmod +x /usr/bin/${_cmdname}.exe || csih_error "chmod /usr/bin/${_cmdname}.exe failed"
    fi
    
    _path=/etc/slapos/scripts
    csih_inform "create path: ${_path}"
    mkdir -p ${_path}
    for _name in slapos-include.sh slapos-cygwin-bootstrap.sh slapos-configure.sh slapos-cleanup.sh ; do
        [[ -x ${_path}/${_name} && -z "${_install_mode}" ]] && continue
        wget -c http://git.erp5.org/gitweb/slapos.package.git/blob_plain/heads/cygwin:/windows/scripts/${_name} -O ${_path}/${_name} ||
        csih_error "download ${_name} failed"
        csih_inform "download script ${_path}/${_name} OK"
    done

    # Set prefix for slapos
    if [[ -n "${slapos_prefix}" ]] ; then
        echo "Set slapos prefix as ${slapos_prefix}"
        sed -i -e "s%slapos_prefix=.*\$%slapos_prefix=${slapos_prefix}%" ${_path|/slapos-include.sh
    fi
}
readonly -f install_slapos_cygwin_package

function install_ipv6_protocol()
{
    csih_inform "Starting configure IPv6 protocol ..."
    netsh interface ipv6 show interface > /dev/null || \
        netsh interface ipv6 install || \
        csih_error "install IPv6 protocol failed"

    csih_inform "Configure IPv6 protocol OK"
    echo ""
}
readonly -f install_ipv6_protocol

# -----------------------------------------------------------
# Start script
# -----------------------------------------------------------
csih_inform "Starting bootstrap slapos node ..."
echo ""

# -----------------------------------------------------------
# Command line options
# -----------------------------------------------------------
_prefix=
_install_mode=
while test $# -gt 0; do
    # Normalize the prefix.
    case "$1" in
    -*=*) optarg=`echo "$1" | sed 's/[-_a-zA-Z0-9]*=//'` ;;
    *) optarg= ;;
    esac

    case "$1" in
    --prefix=*)
    _prefix=$optarg
    ;;
    -f | --force)
    _install_mode=force
    ;;
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

# ======================================================================
# Constants: slapos bootstrap node use prefiix "slapboot-"
# ======================================================================
declare -r slapos_prefix=${_prefix}
declare -r slapos_cygroot=$(cygpath -w /)

# -----------------------------------------------------------
# Sanity Check
# -----------------------------------------------------------
slapos_sanity_check

# -----------------------------------------------------------
# Patch cygwin packages for building slapos
# -----------------------------------------------------------
slapos_patch_cygwin

# -----------------------------------------------------------
# Install slapos cygwin package
# -----------------------------------------------------------
install_slapos_cygwin_package

# -----------------------------------------------------------
# Check IPv6 protocol, install it if it isn't installed
# -----------------------------------------------------------
install_ipv6_protocol

# -----------------------------------------------------------
# End script
# -----------------------------------------------------------
echo ""
csih_inform "Configure slapos bootstrap node successfully."
echo ""

read -n 1 -t 60 -p "Press any key to exit..."
exit 0
