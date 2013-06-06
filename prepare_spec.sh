#!/bin/bash -e
# Script to prepare .spec file for building slapos-node rpm package

VERSION_REGEX=$1
TEMPLATES_DIRECTORY=$2
RPM_DIRECTORY=$TEMPLATES_DIRECTORY/rpm
RE6STNET_SCRIPT=$3

SLAPOS_SPEC=slapos.spec

# Replace version/release/etc… informations in base spec file
sed $VERSION_REGEX $RPM_DIRECTORY/slapos.spec.base.in > $SLAPOS_SPEC

# Post scriplet generation
echo "%post" >> $SLAPOS_SPEC
cat $RE6STNET_SCRIPT >> $SLAPOS_SPEC
cat $RPM_DIRECTORY/post >> $SLAPOS_SPEC

# Preun scriplet generation
echo "%preun" >> $SLAPOS_SPEC
cat $RPM_DIRECTORY/preun >> $SLAPOS_SPEC

# Postun scriplet generation
echo "%postun" >> $SLAPOS_SPEC
cat $RPM_DIRECTORY/postun >> $SLAPOS_SPEC
