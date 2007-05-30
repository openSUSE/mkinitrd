#!/bin/bash
#%requires: killiscsi
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
    sleep 1
    rm -f /var/log/boot.msg
    test "$devpts" = "no" || umount -t devpts /root/dev/pts
    devpts=no
fi
