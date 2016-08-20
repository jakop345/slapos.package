#!/bin/sh -e

# Edit for release
VERSION=1.3.15
# Edit for release
RECIPE_VERSION=1.0.32
# Edit for release
RELEASE=7

CURRENT_DIRECTORY="$(pwd)"
# Development Section 
OBS_DIRECTORY=$CURRENT_DIRECTORY/home:VIFIBnexedi:branches:home:VIFIBnexedi/SlapOS-Node

VERSION_REGEX="s!\%BUILDOUT_URL\%!$BUILDOUT_URL!g;s/\%RECIPE_VERSION\%/$RECIPE_VERSION/g;s/\%VERSION\%/$VERSION/g;s/\%RELEASE\%/$RELEASE/g"
TEMPLATES_DIRECTORY=$CURRENT_DIRECTORY/templates
SLAPOS_ORGINAL_DIRECTORY=slapos-node
SLAPOS_DIRECTORY=slapos-node_$VERSION+$RECIPE_VERSION+$RELEASE

export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt

function prepare_template_files
{

    # Prepare directory for new version if needed
    mkdir -p $CURRENT_DIRECTORY/$SLAPOS_DIRECTORY 
    cp -rf $CURRENT_DIRECTORY/$SLAPOS_ORGINAL_DIRECTORY/* $CURRENT_DIRECTORY/$SLAPOS_DIRECTORY

    rm -rf $CURRENT_DIRECTORY/$SLAPOS_DIRECTORY/slapos/slapos_repository
    cp -R slapos_repository $CURRENT_DIRECTORY/$SLAPOS_DIRECTORY/slapos/
    sed $VERSION_REGEX $TEMPLATES_DIRECTORY/Makefile.in > $CURRENT_DIRECTORY/$SLAPOS_DIRECTORY/slapos/Makefile
}

function prepare_download_cache
{
    cd $CURRENT_DIRECTORY/$SLAPOS_DIRECTORY/slapos/
    rm -rf build/
    bash $CURRENT_DIRECTORY/prepare_download_cache.sh $VERSION $BUILDOUT_URL $RECIPE_VERSION || (echo "Impossible to build SlapOS, exiting." && exit 1)
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
    cd $CURRENT_DIRECTORY/debian
    dch -pm -v $VERSION+$RECIPE_VERSION+$RELEASE  --check-dirname-level=0 "New version of slapos ($VERSION+$RECIPE_VERSION+$RELEASE)"

    # Add cron and logrotate files
    cp $CURRENT_DIRECTORY/$SLAPOS_ORGINAL_DIRECTORY/template/slapos-node.cron.d $CURRENT_DIRECTORY/debian/cron.d
    cp $CURRENT_DIRECTORY/$SLAPOS_ORGINAL_DIRECTORY/template/slapos-node.logrotate $CURRENT_DIRECTORY/debian/slapos-node.logrotate
    cd $CURRENT_DIRECTORY
    tar -czf debian.tar.gz debian
    cp $CURRENT_DIRECTORY/debian.tar.gz $OBS_DIRECTORY
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
