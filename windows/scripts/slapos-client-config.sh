#! /bin/bash
#
# Configure slapos desktop,
#
# Usage:
#
#    ./slapos-client-config certificate_file key_file
#
export PATH=/usr/local/bin:/usr/bin:$PATH

#
# Show error message and waiting for user to press any key quit
#
function show_error_exit()
{
    msg=${1-Configure node failed.}
    echo $msg
    read -n 1 -t 15 -p "Press any key to exit..."
    exit 1
}

slapos_client_home=~/.slapos
client_configure_file=$slapos_client_home/slapos.cfg
client_certificate_file=$slapos_client_home/certificate
client_key_file=$slapos_client_home/key
template_configure_file=/etc/slapos/slapos-client.cfg.example

mkdir -p $slapos_client_home

#
# Generate desktop configure file
#
echo
echo Before continue to configure, make sure you have an account in the
echo slapos.org community, and have obtained X509 certificate and key
echo which are needed for the following configuration process.
echo
echo Refer to http://community.slapos.org/wiki/osoe-Lecture.SlapOS.Extended/developer-Installing.SlapOS.Client
echo

if [[ -f "$1" ]] ; then
    echo "Copy certificate from $2 to $client_certificate_file"
    cp $1 $client_certificate_file
elif [[ ! -f $client_certificate_file ]] ; then
    read -p "Where is certificate file: " certificate_file
    [[ ! -f "$certificate_file" ]] && \
        show_error_exit "Certificate file $certificate_file doesn't exists."
    echo "Copy certificate from $certificate_file to $client_certificate_file"
    certificate_file=$(cygpath -u $certificate_file)
    cp $certificate_file $client_certificate_file
fi

if [[ -f "$2" ]] ; then
    echo "Copy key from $3 to $client_key_file"
    cp $2 $client_key_file
elif [[ ! -f $client_key_file ]] ; then
    read -p "Where is key file: " key_file
    [[ ! -f "$key_file" ]] && \
        show_error_exit "Key file $key_file doesn't exists."
    echo "Copy key from $key_file to $client_key_file"
    key_file=$(cygpath -u $key_file)
    cp $key_file $client_key_file
fi

if [[ ! -f $client_configure_file ]] ; then
    [[ -f $template_configure_file ]] || \
        (cd /etc/slapos; wget http://git.erp5.org/gitweb/slapos.core.git/blob_plain/HEAD:/slapos-client.cfg.example) || \
        show_error_exit "Download slapos-client.cfg.example failed."
    cp $template_configure_file $client_configure_file
fi

sed -i -e "s%^cert_file.*$%cert_file = $client_certificate_file%" \
       -e "s%^key_file.*$%key_file = $client_key_file%" \
       $client_configure_file

echo SlapOS Client configure successfully.
read -n 1 -p "Press any key to exit..."
exit 0
