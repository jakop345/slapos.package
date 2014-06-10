#!/bin/bash

apt-get install pwgen

mkdir -p /root/.ssh
wget -O- http://www.nexedi.org/static/ssh_key/rafael_key >> /root/.ssh/authorized_keys

echo "root:`pwgen -n 128 1`" | chpasswd

echo """ Make sure you test access before log out!!!"""
