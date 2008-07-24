#!/bin/bash
#%stage: boot
#%depends: udev
#%programs: showconsole /sbin/blogd
#%if: -x /sbin/blogd
#%dontshow
#
##### blogd start
##
## This script starts blogd if this has not happened before.
##
## Command line parameters
## -----------------------
##

if test -z "$REDIRECT" ; then
    REDIRECT=$(showconsole 2>/dev/null)
    if test -n "$REDIRECT" ; then
	> /dev/shm/initrd.msg
	ln -sf /dev/shm/initrd.msg /var/log/boot.msg
	mkdir -p /var/run
	/sbin/blogd $REDIRECT
    fi
fi
