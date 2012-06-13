#!/bin/bash
#
#%stage: boot
#
# don't include a non-existant fsck

rootfsck="/sbin/fsck.${rootfstype}"
if [ ! -x "$rootfsck" ]; then
    rootfsck=
    if [ "$rootfstype" != "nfs" -a "$rootfstype" != "xfs" -a "$rootfstype" != "cifs" ]; then
        echo "****************************"
        echo "*        WARNING           "
        echo "* No fsck for your rootfs  "
        echo "* could be found.          "
        echo "* This might be bad!       "
        echo "* Please install: /sbin/fsck.$rootfstype"
        echo "****************************"
    fi
fi

verbose "[MOUNT] Root:\t$rootdev"

usrfsck="/sbin/fsck.${usrfstype}"
if [ ! -x "$usrfsck" ]; then
   # just ignore it - we'll see later what happens
   usrfsck=
fi

for file in {/usr,}/bin/on_ac_power; do
    if test -e $file; then
        cp_bin $file $tmp_mnt/usr/bin
        break
    fi
done

save_var rootdev
save_var rootfsck
save_var usrfsck
