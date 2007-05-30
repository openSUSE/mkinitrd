#!/bin/bash

# force multipath and kpartx usage if multipath was forced
if use_script multipath; then
	root_mpath=1
	root_kpartx=1
fi

if [ -x /sbin/multipath -a -x /sbin/dmsetup ] ; then
	for bd in $blockdev ; do
	    update_blockdev $bd
	    if [ $blockdriver = device-mapper ]; then
		dm_uuid=$(dmsetup info -c --noheadings -o uuid -j $blockmajor -m $blockminor)
		dm_creator=${dm_uuid%-*}
		if [ "$dm_creator" = "mpath" ]; then
		    tmp_root_dm=1 # multipath needs dm
		    root_mpath=1
		fi
	    fi
	done
fi

if [ -n "$root_mpath" ] ; then
        if [ -f /etc/multipath.conf ] ; then
            cp -a /etc/multipath.conf $tmp_mnt/etc
        fi
        cp /etc/udev/rules.d/72-multipath-compat.rules $tmp_mnt/etc/udev/rules.d
fi

save_var root_mpath
