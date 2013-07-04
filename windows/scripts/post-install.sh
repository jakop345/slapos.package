#! /bin/bash
#
# When cygwin is installed, then call this script by Administrator:
#
#    /bin/bash/ --login -i init-cygwin.sh
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
function show_error_exit()
{
    echo Error: $1
    read -n 1 -p "Press any key to exit..."
    exit 1
}

password_filename=/etc/passwd
echo Checking passwd file ...
if [[ ! -f $password_filename ]] ; then
    echo No passwd file found.
    mkpasswd -l > $password_filename || show_error_exit "mkpasswd failed"
    echo Generate passwd file OK.
else
    echo Check passwd file OK.
fi

echo Checking group file ...
if [[ ! -f /etc/group ]] ; then
    echo No group file found.
    mkgroup -l > /etc/group || show_error_exit "mkgroup failed"
    echo Generate group file OK.
else
    echo Check group file OK.
fi

# grep -q "^root:" $password_filename
# if (( $? != 0 )) ; then
#     myaccount=$(grep "^Administrator:" $password_filename | \
#               sed -e "s/Administrator:unused:500:/root:unused:0:/g")
#     if [[ "${myaccount:0:4}" == root ]] ; then
#         echo $myaccount >> $password_filename
#     else
#         exit 1
#     fi
# fi

if [[ ! -f ~/.minttyrc ]] ; then
    echo Creating ~/.minttyrc
    cat <<EOF > ~/.minttyrc
BoldAsFont=no
Font=Courier New
FontHeight=16
Scrollbar=none
EOF
    echo File ~/.minttyrc created
fi

if [[ ! -f /cygtty.bat ]] ; then
    echo Creating /cygtty.bat
    cyghome=$(cygpath -w /)
    cat <<EOF > /cygtty.bat
@echo off

${cyghome:0:2}
chdir ${cyghome}\\bin

start mintty.exe -i /Cygwin-Terminal.ico -
EOF
    chmod +x /cygtty.bat
    echo File /cygtty.bat created.
fi

# Copy rebaseall.bat to /
if [[ ! -f /autorebase.bat ]] ; then
    echo Create /autorebase.bat
    cat <<EOF > /autorebase.bat
@echo off
rem Postinstall scripts are always started from the Cygwin root dir
rem so we can just call dash from here
path .\bin;%path%
dash /bin/rebaseall -p
EOF
    chmod +x /autorebase.bat
    echo /autorebase.bat created.
fi

# Change format of readme.txt
readme_filepath=$(cygpath -m /)/..
if [[ -f $readme_filepath/Readme.txt ]] ; then
    unix2dos $readme_filepath/Readme.txt
    echo Change readme.txt to dos format OK.
fi

# Remove cygwin services to be sure these services will be configured
# in this cygwin enviroments when there are many cygwin instances
# installed in this computer.
for x in $(cygrunsrv --list) ; do
    echo Removing cygservice $x
    cygrunsrv -R $x
done

# Backup slap-runner.html
cp /etc/slapos/scripts/slap-runner.html{,.orig}

echo Run post-install script successfully.
read -n 1 -t 60 -p "Press any key to exit..."
exit 0
