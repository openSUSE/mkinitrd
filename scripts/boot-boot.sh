#!/bin/bash
#
#%stage: setup
#%depends: killprogs
#%programs:
#%modules:
#%dontshow
#
##### boot
##
## Boot into the new root.
##
## Command line parameters
## -----------------------
##

# Move device nodes
/bin/mount --move /dev /root/dev
/bin/mount -t proc proc /root/proc
# ready to leave
cd /root
umount -l /proc
umount -l /sys

# Remove exported functions
unset check_for_device

# Export root fs information
ROOTFS_BLKDEV="$rootdev"
export ROOTFS_BLKDEV

# upstart does not export the full environment to jobs by default
# and we want our boot.* scripts to know the initrd environment for
# quite a while
# technically we only need the variables exported by initrd scripts
# and the cmdline and we'll also get thinks like HOME and PWD, but
# those are overwritten anyway
export > /root/dev/shm/initrd_exports.sh

exec /bin/run-init -c ./dev/console /root $init ${kernel_cmdline[@]}
echo could not exec run-init!
die 0
