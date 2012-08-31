#!/bin/bash -e

VERSION=0.28.2
RECIPE_VERSION=0.101

CURRENT_DIRECTORY="$(pwd)"
TEMPLATES_DIRECTORY=$CURRENT_DIRECTORY/templates
SLAPOS_ORGINAL_DIRECTORY=slapos-node
SLAPOS_DIRECTORY=slapos-node_$VERSION+$RECIPE_VERSION+0
OBS_DIRECTORY=$CURRENT_DIRECTORY/home:VIFIBnexedi:branches:home:VIFIBnexedi/SlapOS-Node


# Prepare directory for new version if needed 
if [ ! -d "$CURRENT_DIRECTORY/$SLAPOS_DIRECTORY" ]; then
    cp -r $CURRENT_DIRECTORY/$SLAPOS_ORGINAL_DIRECTORY $CURRENT_DIRECTORY/$SLAPOS_DIRECTORY
fi

# Prepare Makefile and offline script
sed "s/\%RECIPE_VERSION\%/$RECIPE_VERSION/g;s/\%VERSION\%/$VERSION/g" $TEMPLATES_DIRECTORY/Makefile.in > $CURRENT_DIRECTORY/$SLAPOS_DIRECTORY/slapos/Makefile
sed "s/\%RECIPE_VERSION\%/$RECIPE_VERSION/g;s/\%VERSION\%/$VERSION/g" $TEMPLATES_DIRECTORY/offline.sh.in > $CURRENT_DIRECTORY/$SLAPOS_DIRECTORY/slapos/offline.sh

# Prepare Download Cache for SlapOS 
cd $CURRENT_DIRECTORY/$SLAPOS_DIRECTORY/slapos/
#rm -rf build/
bash offline.sh

# Prepare tarball
cd $CURRENT_DIRECTORY
tar -czf $SLAPOS_DIRECTORY.tar.gz $SLAPOS_DIRECTORY


#################    Prepare obs   ###################################
cd $CURRENT_DIRECTORY/home:VIFIBnexedi/SlapOS-Node

# Remove former configuration
osc rm -f $SLAPOS_ORGINAL_DIRECTORY*.tar.gz
osc rm -f slapos.spec

# Prepare new tarball
cp $CURRENT_DIRECTORY/$SLAPOS_DIRECTORY.tar.gz .
osc add $SLAPOS_DIRECTORY.tar.gz

# Prepare new specfile
sed "s/\%RECIPE_VERSION\%/$RECIPE_VERSION/g;s/\%VERSION\%/$VERSION/g" $TEMPLATES_DIRECTORY/slapos.spec.in > slapos.spec
osc add slapos.spec

##################### Prepare configuration file for .deb ############
# Add entry to changelog
cd $TEMPLATES_DIRECTORY/debian
dch -pm -v $VERSION+$RECIPE_VERSION+0  --check-dirname-level=0 "New version of slapos ($VERSION+$RECIPE_VERSION)"

cd $TEMPLATES_DIRECTORY 
tar -czf debian.tar.gz debian
cd $OBS_DIRECTORY
cp $TEMPLATES_DIRECTORY/debian.tar.gz .
#prepare new .dsc file
osc rm -f slapos*.dsc
sed "s/\%RECIPE_VERSION\%/$RECIPE_VERSION/g;s/\%VERSION\%/$VERSION/g" $TEMPLATES_DIRECTORY/slapos.dsc.in > $SLAPOS_DIRECTORY.dsc
osc add $SLAPOS_DIRECTORY.dsc 

## Upload new Package
osc commit -m " New SlapOS Recipe $RECIPE_VERSION"

# Save current version
echo "$RECIPE_VERSION" > $CURRENT_DIRECTORY/slapos-recipe-version  
echo "$VERSION" > $CURRENT_DIRECTORY/slapos-version  