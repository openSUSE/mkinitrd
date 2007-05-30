#!/bin/bash
#%requires: evms
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
## vg_root		use this group as Volume Group
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
	       if [ "$#" = "3" ] && [ "$2" != "cciss" ] ; then
	           vg_root=$2
	       fi
	       ;;
	esac
	
fi

# initialize remebered and parameterized devices
for $vgr in $lvm $vg_root; do
	vgchange -a y $vgr
done
