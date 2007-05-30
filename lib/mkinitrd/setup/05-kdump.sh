#!/bin/bash

# Check whether this is the kdump kernel
if [ "${kernel_image%%-kdump}" != "${kernel_image}" ] ; then
    if [ -f /etc/sysconfig/kdump ] ; then
	. /etc/sysconfig/kdump
	dumpdev=$KDUMP_DUMPDEV
    fi
    is_kdump=1
fi

save_var dumpdev
save_var is_kdump
