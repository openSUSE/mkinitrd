#!/bin/bash
#
#%stage: boot
#
#%dontshow
#
##### Device functions
##
## This script provides helper functions for major/minor analyzation.
## Usually this should not have to be changed in any way and only exists
## here because I have not found any better place to put it to.
##
## Command line parameters
## -----------------------
##

# Convert a major:minor pair into a device number
mkdevn() {
    local major=$1 minor=$2 minorhi minorlo
    major=$(($major * 256))
    minorhi=$(($minor / 256))
    minorlo=$(($minor % 256))
    minor=$(($minorhi * 256 * 4096))
    echo $(( $minorlo + $major + $minor ))
}

# Extract the major part from a device number
devmajor() {
    local devn=$(($1 / 256))
    echo $(( $devn % 4096 ))
}

# Extract the minor part from a device number
devminor() {
    local devn=${1:-0}
    echo $(( $devn % 256 )) 
}

# (We are using a devnumber binary inside the initrd.)
devnumber() {
    set -- $(ls -lL $1)
    mkdevn ${5%,} $6
}

# Waiting for a device to appear
# device node will be created by udev
check_for_device() {
    local root
    local retval=1
    local timeout=$udev_timeout
    local udev_devn
    local udev_major

    root=$1
    if [ -n "$root" ]; then
	echo -n "Waiting for device $root to appear: "
	while [ $timeout -gt 0 ]; do
	    if [ -e $root ]; then
		udev_devn=$(devnumber $root)
		udev_major=$(devmajor $udev_devn)
		if [ -n "$root_major" ] ; then
		    if [ "$udev_major" == "$root_major" ] ; then
			echo " ok"
			retval=0
			break;
		    else
			echo -n "!"
			multipath -v0
			wait_for_events
			sleep 1
			timeout=$(( $timeout - 1 ))
			continue;
		    fi
		else
		    echo " ok"
		    retval=0
		    break;
		fi  
	    fi
	    sleep 1
	    echo -n "."
	    timeout=$(( $timeout - 1 ))
	    # Recheck for LVM volumes
	    if [ -n "$vg_root" -a -n "$vg_roots" ] ; then
		vgscan
	    fi
	    for vgr in $vg_root $vg_roots; do
		vgchange -a y $vgr
	    done
	done
    fi
    return $retval;
}

