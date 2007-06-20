#!/bin/bash
#%dontshow
#
##### blogd end2
##
## Really kill blogd this time.
##
## Command line parameters
## -----------------------
##

if test -n "$blogd_pid" ; then
    kill -QUIT "$blogd_pid"
    wait "$blogd_pid"
    umount -t devpts /root/dev/pts
fi
