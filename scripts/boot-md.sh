#!/bin/bash
#%stage: softraid
#%programs: /sbin/mdadm
#%modules: raid0 raid1 raid456
#%if: -n "$need_mdadm"
#
##### MD (Software-)Raid
##
## This activates and waits for an MD software raid.
##
## Command line parameters
## -----------------------
##
## need_mdadm=1		use MD raid
## md_uuid		the uuid of the raid to activate
## 

# load the necessary module before we initialize the raid system
load_modules

[ "$mduuid" ] && md_uuid="$mduuid"

md_major=$(sed -ne 's/\s*\([0-9]\+\)\s*md$/\1/p' /proc/devices)
if [ -n "$md_major" -a "$md_major" = "$maj" ]; then
    md_minor="$min"
    md_dev="/dev/md$md_minor"
fi

# Always start md devices read/only. They will get set to rw as soon
# as the first write occurs. This way we can guarantee that no
# restore occurs before resume.
if [ -f /sys/module/md_mod/parameters/start_ro ]; then
    echo 1 > /sys/module/md_mod/parameters/start_ro
fi

if [ -n "$need_mdadm" ]; then
	
	if [ -f /etc/mdadm.conf ] ; then
	    mdconf="-Ac /etc/mdadm.conf"
	    [ -z "$md_dev" ] && md_dev="--scan"
	fi
	
	if [ -n "$md_uuid" ] ; then
	    mdarg="--uuid=$md_uuid"
	elif [ -n "$md_uuid" ] ; then
	    mdarg="$mdarg --uuid=$md_uuid"
	fi
	if [ -n "$md_minor" ] ; then
	    mdarg="$mdarg --super-minor=$md_minor"
	    md_dev="/dev/md$md_minor"
	elif [ -z "$md_minor" -a -n "$md_minor" ] ; then
	    mdarg="$mdarg --super-minor=$md_minor"
	fi
	
	case $resumedev in
	    /dev/md*)
	        echo 1 > /sys/module/md_mod/parameters/start_ro
	        resume_minor="${resumedev#/dev/md}"
	        mdadm -Ac partitions -m $resume_minor --auto=md $resumedev
	        ;;
	esac
	
	if [ "$md_dev" ] ; then
	    /sbin/mdadm $mdconf --auto=md $md_dev || /sbin/mdadm -Ac partitions $mdarg --auto=md $md_dev
	fi
fi

