#!/bin/sh -e

# Edit for release
VERSION=0.426
# Edit for release
RECIPE_VERSION=0.265
# Edit for release
RELEASE=2
GITHASH=1ddbb2be20b224e7618bd7904bf846fd947b8b16

CURRENT_DIRECTORY="$(pwd)"
# Define URL to compile
BUILDOUT_URL=http://git.erp5.org/gitweb/slapos.git/blob_plain/refs/tags/slapos-$RECIPE_VERSION:/component/re6stnet/buildout.cfg
OBS_DIRECTORY=$CURRENT_DIRECTORY/home:VIFIBnexedi/Re6stnet

# Development Section [Uncomment for use] 
OBS_DIRECTORY=$CURRENT_DIRECTORY/home:VIFIBnexedi:branches:home:VIFIBnexedi/Re6stnet
BUILDOUT_URL=http://git.erp5.org/gitweb/slapos.git/blob_plain/$GITHASH:/component/re6stnet/buildout.cfg


VERSION_REGEX="s!\%BUILDOUT_URL\%!$BUILDOUT_URL!g;s/\%RECIPE_VERSION\%/$RECIPE_VERSION/g;s/\%VERSION\%/$VERSION/g;s/\%RELEASE\%/$RELEASE/g"
TEMPLATES_DIRECTORY=$CURRENT_DIRECTORY/templates
RE6ST_ORGINAL_DIRECTORY=re6st-node
RE6ST_DIRECTORY=re6st-node_$VERSION+$RECIPE_VERSION+$RELEASE

function prepare_template_files
{

    # Prepare directory for new version if needed
    mkdir -p $CURRENT_DIRECTORY/$RE6ST_DIRECTORY 
    cp -rf $CURRENT_DIRECTORY/$RE6ST_ORGINAL_DIRECTORY/* $CURRENT_DIRECTORY/$RE6ST_DIRECTORY

    sed $VERSION_REGEX $TEMPLATES_DIRECTORY/Makefile.in > $CURRENT_DIRECTORY/$RE6ST_DIRECTORY/re6stnet/Makefile
    sed $VERSION_REGEX $TEMPLATES_DIRECTORY/offline.sh.in > $CURRENT_DIRECTORY/$RE6ST_DIRECTORY/re6stnet/offline.sh
}

function prepare_download_cache
{
    cd $CURRENT_DIRECTORY/$RE6ST_DIRECTORY/re6stnet/
    rm -rf build/
    bash offline.sh || (echo "Impossible to build Re6stnet, exiting." && exit 1)
    # Go back to starting point
    cd $CURRENT_DIRECTORY
}

function prepare_tarball
{
    tar -czf $RE6ST_DIRECTORY.tar.gz $RE6ST_DIRECTORY
}

function prepare_deb_packaging
{

    # Add entry to changelog
    cd $TEMPLATES_DIRECTORY/debian
    #dch -pm -v $VERSION+$RECIPE_VERSION+$RELEASE  --check-dirname-level=0 "New version of re6st ($VERSION+$RECIPE_VERSION+$RELEASE)"

    # Add cron and logrotate files
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
    osc rm -f $RE6ST_ORGINAL_DIRECTORY*.tar.gz
    osc rm -f re6stnet.spec

    # Prepare new tarball
    cp $CURRENT_DIRECTORY/$RE6ST_DIRECTORY.tar.gz .
    osc add $RE6ST_DIRECTORY.tar.gz

    # Prepare new specfile
    sed $VERSION_REGEX $TEMPLATES_DIRECTORY/re6stnet.spec.in > re6stnet.spec
    osc add re6stnet.spec

    # Prepare new .dsc file
    osc rm -f re6st*.dsc
    sed $VERSION_REGEX $TEMPLATES_DIRECTORY/re6stnet.dsc.in > $RE6ST_DIRECTORY.dsc
    osc add $RE6ST_DIRECTORY.dsc

    osc rm -f PKGBUILD
    SOURCEMD5=`md5sum $RE6ST_DIRECTORY.tar.gz | cut -d\  -f1`
    sed "$VERSION_REGEX;s/\%SOURCEMD5\%/$SOURCEMD5/g" $TEMPLATES_DIRECTORY/PKGBUILD.in > PKGBUILD

    cp $TEMPLATES_DIRECTORY/re6stnet.install .
    osc add PKGBUILD re6stnet.install

    ## Upload new Package
    osc commit -m "New Re6stnet Recipe $RECIPE_VERSION"

}

prepare_template_files

prepare_download_cache

prepare_tarball

prepare_deb_packaging

obs_upload
