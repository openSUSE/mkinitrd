#!/bin/bash
#
#%stage: boot
#
# don't include a non-existant fsck

rootfsck="$(type -p fsck.${rootfstype})"
if [ -z "$rootfsck" ]; then
    if [ "$rootfstype" != "nfs" -a "$rootfstype" != "xfs" -a "$rootfstype" != "cifs" ]; then
        echo "****************************"
        echo "*        WARNING           "
        echo "* No fsck for your rootfs  "
        echo "* could be found.          "
        echo "* This might be bad!       "
        echo "* Please install: fsck.$rootfstype"
        echo "****************************"
    fi
fi

verbose "[MOUNT] Root:\t$rootdev"

usrfsck="$(type -p fsck.${usrfstype})"

for file in {/usr,}/bin/on_ac_power; do
    if test -e $file; then
        cp_bin $file $tmp_mnt/usr/bin
        break
    fi
done
if test -e /etc/e2fsck.conf
then
	cp -aL "$_" "$tmp_mnt$_"
fi

save_var rootdev
save_var rootfsck
save_var usrfsck
