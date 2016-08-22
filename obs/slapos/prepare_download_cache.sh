#!/bin/bash

source release_configuration.sh

##########
# VERSION comes from release_configuration.sh
# RECIPE_VERSION comes from release_configuration.sh

TARGET_DIRECTORY=/opt/slapos
BUILD_ROOT_DIRECTORY="$CURRENT_DIRECTORY/$SLAPOS_DIRECTORY/slapos/build"
BUILD_DIRECTORY=$BUILD_ROOT_DIRECTORY$TARGET_DIRECTORY

#rm -rf $BUILD_ROOT_DIRECTORY

#./configure --prefix=/opt/slapos/parts/<NAME>

echo "Preparing source tarball (recipe version: $RECIPE_VERSION)"
echo " Build Directory: $BUILD_DIRECTORY "
echo " Buildroot Directory: $BUILD_ROOT_DIRECTORY "

mkdir -p $BUILD_DIRECTORY/{eggs,extends-cache,download-cache,download-cache/dist}

set -e

sed  "s/\%RECIPE_VERSION\%/$RECIPE_VERSION/g;s|\%PATCHES_DIRECTORY\%|$PATCHES_DIRECTORY|g;s|\%TARGET_DIRECTORY\%|$TARGET_DIRECTORY|g;s|\%BUILD_ROOT_DIRECTORY\%|$BUILD_ROOT_DIRECTORY|g;s|\%BUILD_DIRECTORY\%|$BUILD_DIRECTORY|g" $BUILD_ROOT_DIRECTORY/../buildout.cfg.in > $BUILD_DIRECTORY/buildout.cfg 

# Build first time to get download-cache and extends-cache ready
cd $BUILD_DIRECTORY

echo "$BUILD_ROOT_DIRECTORY" > ./original_directory

# Download  bootstrap file
wget https://bootstrap.pypa.io/bootstrap-buildout.py --no-check-certificate -O bootstrap.py


(python -S bootstrap.py --buildout-version 2.5.1.post2 \
                        --setuptools-version 19.6.2 \
                        --setuptools-to-dir eggs \
                        -f http://www.nexedi.org/static/packages/source/ \
                        -f http://www.nexedi.org/static/packages/source/slapos.buildout/ && \
    ./bin/buildout -v) || (./bin/buildout -v || (echo "Failed to run buildout, exiting." && exit 1))

# remove all files from build keeping only caches
echo "Deleting unecessary files to reduce source tarball size"

# TODO: Figure out why there is no write permission even for
#       the owner
chmod -R u+w .

cp -R eggs/slapos.rebootstrap* $BUILD_ROOT_DIRECTORY/..

rm -fv .installed.cfg environment.*
rm -rfv ./{downloads,parts,eggs,develop-eggs,bin,rebootstrap}

# Removing empty directories
find . -type d -empty -prune -exec rmdir '{}' ';'

mkdir -p $BUILD_DIRECTORY/eggs
python -S bootstrap.py --setuptools-version 19.6.2 \
                       --buildout-version 2.5.1.post2 \
                       --setuptools-to-dir eggs \
                       -f http://www.nexedi.org/static/packages/source/ \
                       -f http://www.nexedi.org/static/packages/source/slapos.buildout/ 

cp -R $BUILD_ROOT_DIRECTORY/../slapos.rebootstrap* eggs

# Removing Python byte-compiled files (as it will be done upon
# package installation) and static libraries
find . -regextype posix-extended -type f \
	-iregex '.*/*\.(py[co]|[l]?a|exe|bat)$$' -exec rm -fv '{}' ';'
