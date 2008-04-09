#!/bin/bash
#%stage: volumemanager
#%depends: evms
#%programs: /sbin/vgscan /sbin/vgchange /sbin/lvm
#%modules: linear
#%if: -n "$root_lvm2"
#
##### LVM (Logical Volume Management)
##
## This activates and waits for an LVM.
##
## Command line parameters
## -----------------------
##
## root_lvm2=1		use LVM
## root=/dev/mapper/... use this device as Volume Group
## vg_roots		use this group as Volume Group
## 

# load the necessary module before we initialize the raid system
load_modules

if [ -n "$root_lvm2" ] ; then
    o=$(get_param root)
    case $o in
	/dev/disk/by-*/*)
	    vg_root=
	    ;;
	/dev/mapper/*)
	    vg_name=${o##root=/dev/mapper/}
	    vg_root=${vg_name%%-*}
	    ;;
	/dev/*)
	    set -- $(IFS=/ ; echo $o)
	    if [ "$#" = "3" ] ; then
		# Check sysfs. If there are subdirectories
		# matching this name it's a block device
		for d in /sys/block/$2\!* ; do
		    if [ -d $d ] ; then
			sysdev=$d
		    fi
		done
		# Not found in sysfs, looks like a VG then
		if [ -z "$sysdev" ] ; then
		    vg_root=$2
		fi
	    fi
	    ;;
    esac
    if [ "$vg_root" ] || [ "$vg_roots" ] ; then
        # We are waiting for a device-mapper device
	root_major=$(sed -n 's/\(.*\) device-mapper/\1/p' /proc/devices)
    fi
fi

# initialize remebered and parameterized devices
for vgr in $vg_root $vg_roots; do
	vgchange -a y $vgr
done
