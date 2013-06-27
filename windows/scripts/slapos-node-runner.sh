#! /bin/bash
#
export PATH=/usr/local/bin:/usr/bin:/bin:$PATH

current_path=$(cygpath -a $(dirname $0))
if [[ ! -f $current_path/node-runner.vbs ]] ; then
    echo Installing slap-runner ...
    $current_path/slapos-configure runner || (echo Failed to create instance of slap-runner ; exit 1)
    echo Install slap-runner OK.
fi

# cat <<EOF > $current_path/node-runner.vbs
#   Set oShell = CreateObject("WScript.Shell")
#   oShell.OpenBrowser("http://[2001:67c:1254:45::c5d5]:50000")
# EOF

if [[ -f $current_path/node-runner.vbs ]] ; then
    echo Starting slap-runner ...
    cyg_cscript $current_path/node-runner.vbs || (echo Failed to start slap-runner ; exit 1)
    echo Start slap-runner OK.
fi
