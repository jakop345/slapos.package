#!/bin/bash

DEBIANVERSION=7.4.0
ISONAME=debian-$DEBIANVERSION-amd64-netinst.iso

set -e 

if [ ! -f $ISONAME ]; then
  wget http://cdimage.debian.org/debian-cd/$DEBIANVERSION/amd64/iso-cd/$ISONAME
fi

mkdir -p loopdir
mount -o loop $ISONAME loopdir
#rm -rf cd
#mkdir cd
rsync -a -H --exclude=TRANS.TBL loopdir/ cd
umount loopdir

mkdir irmod
cd irmod
# This path to install.amd can variate
INITRD_PATH=../cd/install.amd/initrd.gz
gzip -d < $INITRD_PATH | cpio --extract --verbose --make-directories --no-absolute-filenames
cp ../preseed.cfg preseed.cfg
find . | cpio -H newc --create --verbose | gzip -9 > $INITRD_PATH
cd ../
rm -fr irmod/

cd cd
md5sum `find -follow -type f` > md5sum.txt
cd ..

rm -rf $ISONAME.patched
genisoimage -o $ISONAME.patched -r -J -no-emul-boot -boot-load-size 4 -boot-info-table -b isolinux/isolinux.bin -c isolinux/boot.cat ./cd

isohybrid $ISONAME.patched
