#! /bin/bash
#
# When cygwin is installed, then call this script by Administrator:
#
#    /bin/bash/ --login -i post-install.sh PREFIX
#
# It will do:
#
#    * Set uid of Adminstrator to 0, and create root account
#
#    * Create .minttyrc and cygtty.bat, which used to start comand console
#
#    * Create autorebase.bat, it used to fix cygwin dll problem
#
#    * Change readme.txt to dos format
#
#    * Set prefix for this slapos node
#
function show_error_exit()
{
    echo Error: ${1:-"Run post-install script failed."}
    read -n 1 -p "Press any key to exit..."
    exit 1
}
readonly -f show_error_exit

declare -r slapos_prefix=$1
declare -r _cygroot=$(cygpath -w /)

_charset=$(ipwin codepage) || _charset=""
echo "Windows OEM Codepage is ${_charset}"


# Change format of readme.txt
_filename=$(cygpath -u $(cygpath -m /)/../readme.txt)
if [[ -f ${_filename} ]] ; then
    echo "Changing $(cygpath -w ${_filename}) as dos format ..."
    unix2dos ${_filename} && echo OK.
fi

# Backup slap-runner.html
_filename=/etc/slapos/scripts/slap-runner.html
if [[ -r ${_filename} ]] ; then
    echo "Backuping ${_filename} as ${_filename}.orig"
    cp ${_filename}{,.orig} && echo OK.
else
    echo "Warning: missing ${_filename}"
fi

# Unzip slapos.tar.gz
_filename=/opt/downloads/slapos.tar.gz
if [[ -r ${_filename} ]] ; then
    echo "Extracting ${_filename} ..."
    (cd /opt ; tar xzf ${_filename} --no-same-owner) || show_error_exit
    echo OK.
elif [[ ! -d /opt/slapos ]] ; then
    echo "Warning: missing ${_filename}"
fi

# Set prefix for slapos
if [[ -n ${slapos_prefix} ]] ; then
    echo "Set slapos prefix as ${slapos_prefix}"
    sed -i -e "s%slapos_prefix=.*\$%slapos_prefix=${slapos_prefix}%" \
        /etc/slapos/scripts/slapos-include.sh
else
    echo "Set slapos prefix to empty"
fi

echo
echo "Run post-install.sh script successfully."
echo
read -n 1 -t 60 -p "Press any key to exit..."
exit 0
