#!/bin/bash
#
#%stage: boot
#%depends: progs sharedlibs
#

COMPRESS="gzip -9"

if [[ $(uname -m) =~ ppc ]]
then
    COMPRESS="xz --check=crc32"
fi
pushd . > /dev/null 2>&1
cd $tmp_mnt
find bin sbin -type f -print0 | xargs -0 chmod 0755
if ! find . ! -name "*~" | cpio -H newc --create | $COMPRESS > $tmp_initrd
then
    oops 8 "Failed to build initrd"
fi
popd > /dev/null 2>&1
if ! cp -f $tmp_initrd $initrd_image ; then
    oops 8 "Failed to install initrd"
fi
rm -rf $tmp_mnt

