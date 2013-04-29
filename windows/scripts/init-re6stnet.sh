#! /bin/bash

cd /opt
if [[ -f /miniupnpc.tar.gz ]] ; then
    tar xzf miniupnpc.tar.gz
    mv $(ls miniupnpc-*) miniupnpc
    cd /opt/miniupnpc
    python setup.py install
if

cd /opt
if [[ -f /re6stnet.tar.gz ]] ; then
    tar xzf re6stnet.tar.gz
    mv $(ls re6stnet-*) re6stnet
else
    git clone -b cygwin -n http://git.erp5.org/repos/re6stnet.git 
if

cd /opt/re6stnet
python setup.py install

mkdir /etc/re6stnet
cd /etc/re6stnet

re6st-conf --registry http://re6st.example.com/
