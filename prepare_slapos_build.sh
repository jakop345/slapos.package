#!/bin/bash -e

VERSION=0.35
RECIPE_VERSION=0.148
RELEASE=2

VERSION_REGEX="s/\%RECIPE_VERSION\%/$RECIPE_VERSION/g;s/\%VERSION\%/$VERSION/g;s/\%RELEASE\%/$RELEASE/g"
CURRENT_DIRECTORY="$(pwd)"
TEMPLATES_DIRECTORY=$CURRENT_DIRECTORY/templates
DEB_DIRECTORY=$TEMPLATES_DIRECTORY/deb
RPM_DIRECTORY=$TEMPLATES_DIRECTORY/rpm
SLAPOS_ORIGINAL_DIRECTORY=slapos-node
SLAPOS_DIRECTORY=slapos-node_$VERSION+$RECIPE_VERSION+$RELEASE
OBS_DIRECTORY=$CURRENT_DIRECTORY/home:VIFIBnexedi:branches:home:VIFIBnexedi/SlapOS-Node

RE6STNET_SCRIPT=$TEMPLATES_DIRECTORY/re6stnet.sh

function prepare_template_files
{
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

function spec_generation
{
    SLAPOS_SPEC=slapos.spec

    # Replace version/release/etc… informations in base spec file
    sed $VERSION_REGEX $RPM_DIRECTORY/slapos.spec.base.in > $SLAPOS_SPEC

    # Scriplet insertion
    echo "%post" >> $SLAPOS_SPEC
    cat $RE6STNET_SCRIPT >> $SLAPOS_SPEC
    cat $RPM_DIRECTORY/post.sh >> $SLAPOS_SPEC
    
    echo "%preun" >> $SLAPOS_SPEC
    cat $RPM_DIRECTORY/preun.sh >> $SLAPOS_SPEC

    echo "%postun" >> $SLAPOS_SPEC
    cat $RPM_DIRECTORY/postun.sh >> $SLAPOS_SPEC

}

function prepare_deb_packaging
{
    # Add entry to changelog
    dch -pm -v $VERSION+$RECIPE_VERSION+$RELEASE --changelog $DEB_DIRECTORY/debian/changelog --check-dirname-level=0 "New version of slapos ($VERSION+$RECIPE_VERSION+$RELEASE)"

    # Add cron and logrotate files
    cp -R $DEB_DIRECTORY/debian $OBS_DIRECTORY/
    cp $CURRENT_DIRECTORY/$SLAPOS_ORIGINAL_DIRECTORY/template/slapos-node.cron.d $OBS_DIRECTORY/debian/cron.d
    cp $CURRENT_DIRECTORY/$SLAPOS_ORIGINAL_DIRECTORY/template/slapos-node.logrotate $OBS_DIRECTORY/debian/slapos-node.logrotate
    
    # Create postinst
    cat $RE6STNET_SCRIPT >> $OBS_DIRECTORY/debian/postinst.base
    cat $OBS_DIRECTORY/debian/postinst.exit >> $OBS_DIRECTORY/debian/postinst.base
    mv $OBS_DIRECTORY/debian/postinst.base $OBS_DIRECTORY/debian/postinst
    rm $OBS_DIRECTORY/debian/postinst.exit

    # Create tarball
    cd $OBS_DIRECTORY
    tar -czf debian.tar.gz debian
    cd $CURRENT_DIRECTORY
    rm -Rf $OBS_DIRECTORY/debian
    
    # Generate .dsc
    sed $VERSION_REGEX $DEB_DIRECTORY/slapos.dsc.in > $SLAPOS_DIRECTORY.dsc
}

function obs_upload
{
    # Prepare obs
    cd $OBS_DIRECTORY
    # Update directory
    osc up

    # Remove former configuration
    osc rm -f $SLAPOS_ORIGINAL_DIRECTORY*.tar.gz
    osc rm -f slapos.spec
    osc rm -f slapos*.dsc

    # Add tarball
    cp $CURRENT_DIRECTORY/$SLAPOS_DIRECTORY.tar.gz .
    osc add $SLAPOS_DIRECTORY.tar.gz

    # Add spec
    cp $CURRENT_DIRECTORY/slapos.spec .
    osc add slapos.spec

    # Add .dsc
    cp $CURRENT_DIRECTORY/$SLAPOS_DIRECTORY.dsc .
    osc add $SLAPOS_DIRECTORY.dsc

    # Upload new Package
    osc commit -m "New SlapOS Recipe $RECIPE_VERSION"

    # Go back to starting point
    cd $CURRENT_DIRECTORY
}

# Prepare directory for new version if needed
if [ ! -d "$CURRENT_DIRECTORY/$SLAPOS_DIRECTORY" ]; then
    cp -r $CURRENT_DIRECTORY/$SLAPOS_ORIGINAL_DIRECTORY $CURRENT_DIRECTORY/$SLAPOS_DIRECTORY
fi

# Prepare Makefile and offline script
#prepare_template_files

# Prepare Download Cache for SlapOS
#prepare_download_cache

# Prepare tarball
#prepare_tarball

# Generate spec file
spec_generation

# Prepare deb packaging
#prepare_deb_packaging

# Upload to obs
#obs_upload

# Save current version
echo "$RECIPE_VERSION" > $CURRENT_DIRECTORY/slapos-recipe-version
echo "$VERSION" > $CURRENT_DIRECTORY/slapos-version
