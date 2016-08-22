#!/bin/bash


source release_configuration.sh


cd $OBS_DIRECTORY

# Update directory
osc up

# Remove former configuration
osc rm -f $SLAPOS_ORGINAL_DIRECTORY*.tar.gz
osc rm -f slapos.spec

# Prepare new tarball
cp $CURRENT_DIRECTORY/$SLAPOS_DIRECTORY.tar.gz .
osc add $SLAPOS_DIRECTORY.tar.gz

# Prepare new specfile
sed $VERSION_REGEX $TEMPLATES_DIRECTORY/slapos.spec.in > slapos.spec
osc add slapos.spec

# Prepare new .dsc file
osc rm -f slapos*.dsc
sed $VERSION_REGEX $TEMPLATES_DIRECTORY/slapos.dsc.in > $SLAPOS_DIRECTORY.dsc
osc add $SLAPOS_DIRECTORY.dsc

osc rm -f PKGBUILD
SOURCEMD5=`md5sum $SLAPOS_DIRECTORY.tar.gz | cut -d\  -f1`
sed "$VERSION_REGEX;s/\%SOURCEMD5\%/$SOURCEMD5/g" $TEMPLATES_DIRECTORY/PKGBUILD.in > PKGBUILD

cp $TEMPLATES_DIRECTORY/slapos-node.install .
osc add PKGBUILD slapos-node.install

## Upload new Package
osc commit -m "New SlapOS Recipe $RECIPE_VERSION"

