#!/bin/sh
#
# /sbin/hotplug.sh
# $Id: hotplug.sh,v 1.1 2005/01/20 10:38:11 hare Exp $
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
