#!/bin/sh -e

# Edit for release
VERSION=1.2.1
# Edit for release
RECIPE_VERSION=0.238
# Edit for release
RELEASE=3
GITHASH=a91725787b4836b5c8209a931cc71b2606eb14e1

CURRENT_DIRECTORY="$(pwd)"
# Define URL to compile
BUILDOUT_URL=http://git.erp5.org/gitweb/slapos.git/blob_plain/refs/tags/slapos-$RECIPE_VERSION:/component/slapos/buildout.cfg
OBS_DIRECTORY=$CURRENT_DIRECTORY/home:VIFIBnexedi/SlapOS-Node

# Development Section [Uncomment for use] 
OBS_DIRECTORY=$CURRENT_DIRECTORY/home:VIFIBnexedi:branches:home:VIFIBnexedi/SlapOS-Node
BUILDOUT_URL=http://git.erp5.org/gitweb/slapos.git/blob_plain/$GITHASH:/component/slapos/buildout.cfg


VERSION_REGEX="s!\%BUILDOUT_URL\%!$BUILDOUT_URL!g;s/\%RECIPE_VERSION\%/$RECIPE_VERSION/g;s/\%VERSION\%/$VERSION/g;s/\%RELEASE\%/$RELEASE/g"
TEMPLATES_DIRECTORY=$CURRENT_DIRECTORY/templates
SLAPOS_ORGINAL_DIRECTORY=slapos-node
SLAPOS_DIRECTORY=slapos-node_$VERSION+$RECIPE_VERSION+$RELEASE

function prepare_template_files
{

    # Prepare directory for new version if needed
    mkdir -p $CURRENT_DIRECTORY/$SLAPOS_DIRECTORY 
    cp -rf $CURRENT_DIRECTORY/$SLAPOS_ORGINAL_DIRECTORY/* $CURRENT_DIRECTORY/$SLAPOS_DIRECTORY

    sed $VERSION_REGEX $TEMPLATES_DIRECTORY/Makefile.in > $CURRENT_DIRECTORY/$SLAPOS_DIRECTORY/slapos/Makefile
    sed $VERSION_REGEX $TEMPLATES_DIRECTORY/offline.sh.in > $CURRENT_DIRECTORY/$SLAPOS_DIRECTORY/slapos/offline.sh
}

function prepare_download_cache
{
    cd $CURRENT_DIRECTORY/$SLAPOS_DIRECTORY/slapos/
    rm -rf build/
    bash offline.sh || (echo "Impossible to build SlapOS, exiting." && exit 1)
    # Go back to starting point
    cd $CURRENT_DIRECTORY
}

function prepare_tarball
{
    tar -czf $SLAPOS_DIRECTORY.tar.gz $SLAPOS_DIRECTORY
}

function prepare_deb_packaging
{

    # Add entry to changelog
    cd $TEMPLATES_DIRECTORY/debian
    dch -pm -v $VERSION+$RECIPE_VERSION+$RELEASE  --check-dirname-level=0 "New version of slapos ($VERSION+$RECIPE_VERSION+$RELEASE)"

    # Add cron and logrotate files
    cp $CURRENT_DIRECTORY/$SLAPOS_ORGINAL_DIRECTORY/template/slapos-node.cron.d $TEMPLATES_DIRECTORY/debian/cron.d
    cp $CURRENT_DIRECTORY/$SLAPOS_ORGINAL_DIRECTORY/template/slapos-node.logrotate $TEMPLATES_DIRECTORY/debian/slapos-node.logrotate
    cd $TEMPLATES_DIRECTORY
    tar -czf debian.tar.gz debian
    cd $OBS_DIRECTORY
    cp $TEMPLATES_DIRECTORY/debian.tar.gz .
}

function obs_upload
{
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

}

prepare_template_files

prepare_download_cache

prepare_tarball

prepare_deb_packaging

obs_upload
