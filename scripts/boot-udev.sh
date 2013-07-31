#!/bin/bash
#%stage: boot
#%depends: start dm
#%programs: blkid
#%programs: sg_inq
#%programs: udevadm
#%programs: udevd
#%programs: uname
#%dontshow
#
##### udev initialization
##
## This script starts udev and provides helper functions for later
## functionality based on udev.
##
## Command line parameters
## -----------------------
##

wait_for_events() {
    udevadm settle --timeout=$udev_timeout
}

# Check for debugging
if [ -n "$debug_linuxrc" ]; then
    echo 'udev_log="debug"' >> /etc/udev/udev.conf
else
    echo 'udev_log="error"' >> /etc/udev/udev.conf
fi

# Start udev
udevd --daemon
udevadm trigger --action=add
udevadm trigger --type=subsystems --action=add
wait_for_events
