#!/bin/bash
#%requires: luks
#%if: "$is_kdump"
#
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
## is_kdump=1	use kdump
## 

# TODO: huh? unused?
[ "$CRASH" ] && kdump_kernel="$CRASH"
# Check whether kdump is enabled
if [ -e /proc/vmcore ] ; then
    kdump_kernel=1
fi
if [ "$kdump_kernel" != "1" ] ; then
    kdump_kernel=
fi

# return success if running in a crash environemnt
is_crash_kernel ()
{
    test -f /proc/vmcore || return 1
    # FIXME: any better way to detect crash environment?
    test -n "$CRASH" && return 0
    grep -q elfcorehdr= /proc/cmdline && return 0
    return 1
}

# Do not attempt resuming when running under kdump
if [ "$dumpdev" -a "$kdump_kernel" ] ; then
    resume_mode=off
    unset resumedev
fi

# And now for the real thing
if [ "$dumpdev" ] && is_crash_kernel && udev_discover_dump ; then
    echo "ok, dumping to $dumpdev"
    cp --sparse=always /proc/vmcore $dumpdev
    if [ $? -eq 0 ] ; then
        echo "Dump saved. Rebooting."
        /sbin/reboot -d -f
    fi
    echo "Dumping failed, continue with booting"
fi
