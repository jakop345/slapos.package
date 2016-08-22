#!/bin/bash

source release_configuration.sh

# Prepare directory for new version if needed
mkdir -p $CURRENT_DIRECTORY/$SLAPOS_DIRECTORY

cp -rf $CURRENT_DIRECTORY/$SLAPOS_ORGINAL_DIRECTORY/* $CURRENT_DIRECTORY/$SLAPOS_DIRECTORY
cp $CURRENT_DIRECTORY/debian/cron.d $CURRENT_DIRECTORY/$SLAPOS_DIRECTORY/slapos-node.cron.d        
cp $CURRENT_DIRECTORY/debian/slapos-node.logrotate $CURRENT_DIRECTORY/$SLAPOS_DIRECTORY/slapos-node.logrotate        

rm -rf $CURRENT_DIRECTORY/$SLAPOS_DIRECTORY/slapos/slapos_repository
cp -R slapos_repository $CURRENT_DIRECTORY/$SLAPOS_DIRECTORY/slapos/
sed $VERSION_REGEX $TEMPLATES_DIRECTORY/Makefile.in > $CURRENT_DIRECTORY/$SLAPOS_DIRECTORY/slapos/Makefile
