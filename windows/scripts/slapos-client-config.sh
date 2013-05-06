#! /bin/bash
#
# Configure slapos desktop,
#
# Usage:
#
#    ./slapos-client-config
#

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
        echo "Certificate file $certificate_file doesn't exists." && exit 1
    echo "Copy certificate from $certificate_file to $client_certificate_file"
    cp $certificate_file $client_certificate_file
fi

if [[ -f "$2" ]] ; then
    echo "Copy key from $3 to $client_key_file"
    cp $2 $client_key_file
elif [[ ! -f $client_key_file ]] ; then
    read -p "Where is key file: " key_file
    [[ ! -f "$key_file" ]] && \
        echo "Key file $key_file doesn't exists." && exit 1
    echo "Copy key from $key_file to $client_key_file"
    cp $key_file $client_key_file
fi

if [[ ! -f $client_configure_file ]] ; then
    [[ -f $template_configure_file ]] || \
        (cd /etc/slapos; wget http://git.erp5.org/gitweb/slapos.core.git/blob_plain/HEAD:/slapos-client.cfg.example) || \
        (echo "Download slapos-client.cfg.example failed."; exit 1)
    cp $template_configure_file $client_configure_file
fi

sed -i -e "s%^cert_file.*$%cert_file = $client_certificate_file%" \
       -e "s%^key_file.*$%key_file = $client_key_file%" \
       $client_configure_file
