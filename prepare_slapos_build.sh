#!/bin/bash -e

VERSION=0.35
RECIPE_VERSION=0.148
RELEASE=2

VERSION_REGEX="s/\%RECIPE_VERSION\%/$RECIPE_VERSION/g;s/\%VERSION\%/$VERSION/g;s/\%RELEASE\%/$RELEASE/g"
CURRENT_DIRECTORY="$(pwd)"
TEMPLATES_DIRECTORY=$CURRENT_DIRECTORY/templates
DEB_DIRECTORY=$TEMPLATES_DIRECTORY/deb
SLAPOS_ORGINAL_DIRECTORY=slapos-node
SLAPOS_DIRECTORY=slapos-node_$VERSION+$RECIPE_VERSION+$RELEASE
OBS_DIRECTORY=$CURRENT_DIRECTORY/home:VIFIBnexedi:branches:home:VIFIBnexedi/SlapOS-Node

RE6STNET_SCRIPT=$TEMPLATES_DIRECTORY/re6stnet.sh

function prepare_download_cache{
    cd $CURRENT_DIRECTORY/$SLAPOS_DIRECTORY/slapos/
    rm -rf build/
    bash offline.sh || (echo "Impossible to build SlapOS, exiting." && exit 1)
}

function prepare_tarball{
    cd $CURRENT_DIRECTORY
    tar -czf $SLAPOS_DIRECTORY.tar.gz $SLAPOS_DIRECTORY
}

function spec_generation{
    $CURRENT_DIRECTORY/prepare_spec.sh $VERSION_REGEX $TEMPLATES_DIRECTORY $RE6STNET_SCRIPT
}

function prepare_deb_packaging{
    # Add entry to changelog
    dch -pm -v $VERSION+$RECIPE_VERSION+$RELEASE --changelog $DEB_DIRECTORY/debian/changelog --check-dirname-level=0 "New version of slapos ($VERSION+$RECIPE_VERSION+$RELEASE)"
    # Add cron and logrotate files
    cp -R $DEB_DIRECTORY/debian $OBS_DIRECTORY/
    cp $CURRENT_DIRECTORY/$SLAPOS_ORGINAL_DIRECTORY/template/slapos-node.cron.d $OBS_DIRECTORY/debian/cron.d
    cp $CURRENT_DIRECTORY/$SLAPOS_ORGINAL_DIRECTORY/template/slapos-node.logrotate $OBS_DIRECTORY/debian/slapos-node.logrotate
    cat $RE6STNET_SCRIPT >> $OBS_DIRECTORY/debian/post
    tar -czf $OBS_DIRECTORY/debian.tar.gz $OBS_DIRECTORY/debian
    sed $VERSION_REGEX $DEB_DIRECTORY/slapos.dsc.in > $SLAPOS_DIRECTORY.dsc
}

function obs_upload{
    # Prepare obs
    cd $OBS_DIRECTORY
    # Update directory
    osc up

    # Remove former configuration
    osc rm -f $SLAPOS_ORGINAL_DIRECTORY*.tar.gz
    osc rm -f slapos.spec
    osc rm -f slapos*.dsc

    # Add tarball
    cp $CURRENT_DIRECTORY/$SLAPOS_DIRECTORY.tar.gz .
    osc add $SLAPOS_DIRECTORY.tar.gz

    # Add spec
    cp $CURRENT_DIRECTORY/slapos.spec .
    osc add slapos.spec

    # Add .dsc
    osc add $SLAPOS_DIRECTORY.dsc

    # Upload new Package
    osc commit -m "New SlapOS Recipe $RECIPE_VERSION"
}

# Prepare directory for new version if needed
if [ ! -d "$CURRENT_DIRECTORY/$SLAPOS_DIRECTORY" ]; then
    cp -r $CURRENT_DIRECTORY/$SLAPOS_ORGINAL_DIRECTORY $CURRENT_DIRECTORY/$SLAPOS_DIRECTORY
fi

# Prepare Makefile and offline script
sed $VERSION_REGEX $TEMPLATES_DIRECTORY/Makefile.in > $CURRENT_DIRECTORY/$SLAPOS_DIRECTORY/slapos/Makefile
sed $VERSION_REGEX $TEMPLATES_DIRECTORY/offline.sh.in > $CURRENT_DIRECTORY/$SLAPOS_DIRECTORY/slapos/offline.sh

# Prepare Download Cache for SlapOS
prepare_download_cache

# Prepare tarball
prepare_tarball

# Generate spec file
spec_generation

# Prepare deb packaging
prepare_deb_packaging

# Upload to obs
obs_upload

# Save current version
echo "$RECIPE_VERSION" > $CURRENT_DIRECTORY/slapos-recipe-version
echo "$VERSION" > $CURRENT_DIRECTORY/slapos-version
