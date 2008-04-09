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

kdump_discover_dumpdev() {
    local root
    case "$dumpdev" in
	*:*) root= ;;
	/dev/nfs) root= ;;
	/dev/*)	root=${rootdev#/dev/} ;;
    esac
    if [ -z "$root" ]; then
	return 0
    fi
    if check_for_device $dumpdev  ; then
	# Get major:minor number of the device node
	devn=$(devnumber $rootdev)
	major=$(devmajor $devn)
	minor=$(devminor $devn)
    fi
    if [ -n "$devn" ]; then
	echo "rootfs: major=$major minor=$minor" \
	    "devn=$devn"
	echo $devn > /proc/sys/kernel/real-root-dev
	return 0
    else
	return 1
    fi
}

# Check whether kdump is enabled
if [ -s /proc/vmcore -a -b "$dumpdev" ] ; then
    # Do not attempt resuming when running under kdump
    resume_mode=off
    unset resumedev

    # And now for the real thing
    if kdump_discover_dumpdev ; then
	echo "ok, dumping to $dumpdev"
	cp --sparse=always /proc/vmcore $dumpdev
	if [ $? -eq 0 ] ; then
    	    echo "Dump saved. Rebooting."
    	    /sbin/reboot -d -f
	fi
	echo "Dumping failed, continue with booting"
    fi
fi

unset kdump_discover_dumpdev
