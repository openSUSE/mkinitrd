#!/bin/bash
#
#%stage: devicemapper
#%provides: dmroot
#

if [ -x /sbin/dmraid -a -x /sbin/dmsetup ] ; then
	newbd=
	for bd in $blockdev ; do
	    update_blockdev $bd
	    if [ $blockdriver = device-mapper ]; then
		dm_uuid=$(dmsetup info -c --noheadings -o uuid -j $blockmajor -m $blockminor)
		dm_creator=${dm_uuid%-*}
		if [ "$dm_creator" = "dmraid" ]; then
		    tmp_root_dm=1 # dmraid needs dm
		    root_dmraid=1
		    newbd="$newbd $(echo $bd | sed 's/[0-9]*$//')"
		else
		    newbd="$newbd $bd"
		fi
	    else
		newbd="$newbd $bd"
	    fi
	done
	blockdev="$newbd"
fi

save_var root_dmraid
