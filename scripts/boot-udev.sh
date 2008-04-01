#!/bin/bash
#%stage: boot
#%depends: start dm
#%programs: /sbin/udevd /sbin/udevadm /sbin/udevtrigger /sbin/udevsettle udevinfo /sbin/udevcontrol
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

# Check for debugging
if [ -n "$debug_linuxrc" ]; then
    echo 'udev_log="debug"' >> /etc/udev/udev.conf
else
    echo 'udev_log="error"' >> /etc/udev/udev.conf
fi

# Start udev
echo "Creating device nodes with udev"
/sbin/udevd --daemon
/sbin/udevtrigger
/sbin/udevsettle --timeout=$udev_timeout
