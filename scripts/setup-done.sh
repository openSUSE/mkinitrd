#!/bin/bash
#
#%stage: boot
#%depends: progs sharedlibs
#

COMPRESS="gzip"

if [[ $(uname -m) =~ ppc ]]
then
    COMPRESS="xz --check=crc32"
fi
pushd . > /dev/null 2>&1
cd $tmp_mnt
# suid mount will fail if mkinitrd was called as user
find . -type f \( -perm -4000 -o -perm -2000 \) -exec chmod 755 {} \;
find *bin usr/*bin -type f -exec chmod 755 {} \;
if ! find . ! -name "*~" | cpio --quiet -H newc --create | $COMPRESS > $tmp_initrd
then
    oops 8 "Failed to build initrd"
fi

# uImages want to have uInitrds
if [[ $kernel_image =~ uImage ]]; then
   mkimage -A arm -O linux -T ramdisk -C none -a 0x0 -e 0x0 \
           -n 'Initrd' -d  $tmp_initrd $tmp_initrd.uboot
   rm -f $tmp_initrd
   tmp_initrd=$tmp_initrd.uboot
fi
popd > /dev/null 2>&1
if ! cp -f $tmp_initrd $initrd_image ; then
    oops 8 "Failed to install initrd"
fi
rm -rf $tmp_mnt

