#!/bin/bash
#
#%stage: setup
#
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
