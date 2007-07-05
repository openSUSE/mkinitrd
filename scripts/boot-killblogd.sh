#!/bin/bash
#%requires: remount
#%dontshow
#
##### blogd end
##
## This script tells blogd that the initrd is done.
## Additionally it moves /dev to the new root filesystem.
##
## Command line parameters
## -----------------------
##

blogd_pid=$(pidof blogd)
if test -n "$blogd_pid" ; then
    kill -IO "$blogd_pid"
fi

# not actually anything to do with the blogd but was after the script in the old version
/bin/mount --move /dev /root/dev
