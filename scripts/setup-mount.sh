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

save_var rootdev
save_var rootfsck
