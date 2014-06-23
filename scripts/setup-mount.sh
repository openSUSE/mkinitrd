#!/bin/bash
#
#%stage: boot
#
# don't include a non-existant fsck

rootfsck="/sbin/fsck.${rootfstype}"
if [ ! -x "$rootfsck" ]; then
    rootfsck=
    case "$rootfstype" in
    nfs | nfs4 | xfs | cifs)
        ;;
    *)
        echo "****************************"
        echo "*        WARNING           "
        echo "* No fsck for your rootfs  "
        echo "* could be found.          "
        echo "* This might be bad!       "
        echo "* Please install: /sbin/fsck.$rootfstype"
        echo "****************************"
    esac
fi

verbose "[MOUNT] Root:\t$rootdev"

save_var rootdev
save_var rootfsck
