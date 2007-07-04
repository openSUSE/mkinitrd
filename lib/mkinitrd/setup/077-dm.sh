#!/bin/bash


# no dmsetup -> no dm
if [ -x /sbin/dmsetup ]; then	
    dm_blockdev=
	
    # if any device before was on dm we have to activate it
    [ "$tmp_root_dm" ] && root_dm=1
	
    # resolve dependencies
    for bd in $blockdev ; do
	update_blockdev $bd
	if [ "$blockdriver" = device-mapper ]; then
	    dm_uuid=$(dmsetup info -c --noheadings -o uuid -j $blockmajor -m $blockminor)
	    root_dm=1
	    dm_deps=$(dmsetup deps -j $blockmajor -m $blockminor)
	    dm_deps=${dm_deps#*: }
	    dm_deps=${dm_deps//, /:}
	    dm_deps=${dm_deps//(/}
	    dm_deps=${dm_deps//)/}
	    for dm_dep in $dm_deps; do
		dm_blockdev="$dm_blockdev $(majorminor2blockdev $dm_dep)"
	    done
	else
	    dm_blockdev="$dm_blockdev $bd"
	fi
    done
    blockdev="$dm_blockdev"
	
    # include modules
    if [ -n "$root_dm" ] ; then
	# Add all dm modules
	dm_modules=
	for table in $(dmsetup table | cut -f 4 -d ' ' | sort | uniq); do
	    if [ "$table" ] && [ "$table" != "linear" ] && [ "$table" != "striped" ] ; then
		dm_modules="$dm_modules dm-$table"
	    fi
	done
    fi
    save_var root_dm
fi
