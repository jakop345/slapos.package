#!/bin/bash

# Add entry to changelog
cd $CURRENT_DIRECTORY/debian
dch -pm -v $VERSION+$RECIPE_VERSION+$RELEASE  --check-dirname-level=0 "New version of slapos ($VERSION+$RECIPE_VERSION+$RELEASE)"

cd $CURRENT_DIRECTORY
tar -czf debian.tar.gz debian
cp $CURRENT_DIRECTORY/debian.tar.gz $OBS_DIRECTORY
