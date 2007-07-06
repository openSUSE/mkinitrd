#!/bin/bash
#
#%stage: filesystem
#%provides: dump
#
#%dontshow
##### kdump
##
## This dumps the crash core of a previously crashed kernel
## to a defined partition. 
## This script will automatically be used whenever an
## initrd for a kdump kernel gets created.
##
## Command line parameters
## -----------------------
##
## dumpdev		the device to dump to
## 

# Check whether kdump is enabled
if [ -s /proc/vmcore -a -b "$dumpdev" ] ; then
    # Do not attempt resuming when running under kdump
    resume_mode=off
    unset resumedev

    # And now for the real thing
    if udev_discover_dump ; then
	echo "ok, dumping to $dumpdev"
	cp --sparse=always /proc/vmcore $dumpdev
	if [ $? -eq 0 ] ; then
    	    echo "Dump saved. Rebooting."
    	    /sbin/reboot -d -f
	fi
	echo "Dumping failed, continue with booting"
    fi
fi
