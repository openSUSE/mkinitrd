#!/bin/bash
#
#%stage: devicemapper
#%depends: dmroot
#

# no dmsetup -> no dm
if [ -x /sbin/dmsetup ]; then	
    dm_blockdev=
	
    # if any device before was on dm we have to activate it
    [ "$tmp_root_dm" ] && root_dm=1
	
    blockdev="$(dm_resolvedeps_recursive $blockdev)"
    [ "$?" = 0 ] && root_dm=1
    # include dm when using dm based block devs
    [ "$DM_BLOCK" ] && root_dm=1

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

    # include dm block var from sysconfig
    mkdir -p etc/sysconfig
    grep DM_BLOCK /etc/sysconfig/kernel > etc/sysconfig/kernel
    save_var root_dm
fi
