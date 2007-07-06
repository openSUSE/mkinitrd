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
# ready to leave
cd /root
umount /proc
umount /sys

# Export root fs information
ROOTFS_BLKDEV="$rootdev"
export ROOTFS_BLKDEV

exec /bin/run-init -c ./dev/console /root $init ${kernel_cmdline[@]}
echo could not exec run-init!
die 0
