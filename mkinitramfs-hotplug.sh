#!/bin/sh
#
# /sbin/hotplug.sh
# $Id: mkinitramfs-hotplug.sh,v 1.2 2004/08/02 09:01:17 hare Exp $
#
# Simple hotplug script for initramfs
# Records all events if requested and starts up udev
#

# Records all events if requested
if [ -d /events -a -x /sbin/hotplugeventrecorder ] ; then
    /sbin/hotplugeventrecorder $1 2>/dev/null
fi

AGENT=/sbin/udev

if [ -x $AGENT ]; then
    exec $AGENT $@
    echo "couldn't exec $AGENT"
fi

exit 1
