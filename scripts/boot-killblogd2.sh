#!/bin/bash
#
#%stage: setup
#%depends: killblogd
#%provides: killprogs
#
#%programs: usleep
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
    while [ -d "/proc/$blogd_pid" ]; do
	usleep 300000
    done
    if [ "$devpts" = "yes" ] ; then
	umount -t devpts /dev/pts
    fi
fi
