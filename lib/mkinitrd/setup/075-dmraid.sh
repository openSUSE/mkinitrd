#!/bin/bash

if [ -x /sbin/dmraid -a -x /sbin/dmsetup ] ; then
	for bd in $blockdev ; do
	    update_blockdev $bd
	    if [ $blockdriver = device-mapper ]; then
		dm_uuid=$(dmsetup info -c --noheadings -o uuid -j $blockmajor -m $blockminor)
		dm_creator=${dm_uuid%-*}
		if [ "$dm_creator" = "dmraid" ]; then
		    tmp_root_dm=1 # dmraid needs dm
		    root_dmraid=1
		fi
	    fi
	done
fi
 
save_var root_dmraid
