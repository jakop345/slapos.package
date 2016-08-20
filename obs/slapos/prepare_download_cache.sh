#!/bin/bash

VERSION=$1
RECIPE_VERSION=$3
BUILDOUT_URL=$2

TARGET_DIRECTORY=/opt/slapos
BUILD_ROOT_DIRECTORY="$(pwd)/build"
BUILD_DIRECTORY=$BUILD_ROOT_DIRECTORY$TARGET_DIRECTORY

#./configure --prefix=/opt/slapos/parts/<NAME>

echo "Preparing source tarball (recipe version: $RECIPE_VERSION)"
echo " Build Directory: $BUILD_DIRECTORY "
echo " Buildroot Directory: $BUILD_ROOT_DIRECTORY "

mkdir -p $BUILD_DIRECTORY/{extends-cache,download-cache}

set -e

echo "$BUILD_ROOT_DIRECTORY" > ./original_directory

sed  "s!\%BUILDOUT_URL\%!$BUILDOUT_URL!g;s/\%RECIPE_VERSION\%/$RECIPE_VERSION/g;s|\%PATCHES_DIRECTORY\%|$PATCHES_DIRECTORY|g;s|\%TARGET_DIRECTORY\%|$TARGET_DIRECTORY|g;s|\%BUILD_ROOT_DIRECTORY\%|$BUILD_ROOT_DIRECTORY|g;s|\%BUILD_DIRECTORY\%|$BUILD_DIRECTORY|g" buildout.cfg.in > $BUILD_DIRECTORY/buildout.cfg 

# Build first time to get download-cache and extends-cache ready
cd $BUILD_DIRECTORY

wget https://bootstrap.pypa.io/bootstrap-buildout.py --no-check-certificate -O bootstrap.py
(python -S bootstrap.py --buildout-version 2.5.1.post2 --setuptools-to-dir eggs -f http://www.nexedi.org/static/packages/source/ -f http://www.nexedi.org/static/packages/source/slapos.buildout/ && \
    ./bin/buildout) || (echo "Failed to run buildout, exiting.")

./bin/buildout || (echo "Failed to run buildout, exiting." && exit 1)

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

python -S bootstrap.py --buildout-version 2.5.1.post2 --setuptools-to-dir eggs -f http://www.nexedi.org/static/packages/source/ -f http://www.nexedi.org/static/packages/source/slapos.buildout/ 

cp -R $BUILD_ROOT_DIRECTORY/../slapos.rebootstrap* eggs

# Removing Python byte-compiled files (as it will be done upon
# package installation) and static libraries
find . -regextype posix-extended -type f \
	-iregex '.*/*\.(py[co]|[l]?a|exe|bat)$$' -exec rm -fv '{}' ';'
