#!/bin/bash
#%stage: boot
#%depends: start dm
#%programs: /sbin/udevd /sbin/udevadm /bin/uname
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
    /sbin/udevadm settle --timeout=$udev_timeout
}

# Check for debugging
if [ -n "$debug_linuxrc" ]; then
    echo 'udev_log="debug"' >> /etc/udev/udev.conf
else
    echo 'udev_log="error"' >> /etc/udev/udev.conf
fi

# Start udev
echo "Creating device nodes with udev"
/sbin/udevd --daemon
/sbin/udevadm trigger
wait_for_events
