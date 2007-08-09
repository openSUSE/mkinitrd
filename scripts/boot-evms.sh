#!/bin/bash
#%stage: volumemanager
#%programs: /sbin/evms_activate /sbin/evms
#%if: "$root_evms"
#
##### EVMS (Enterprise Volume Management System)
##
## This activates and waits for an EVMS.
##
## Command line parameters
## -----------------------
##
## root_evms=1		use EVMS
## 

# load the necessary module before we initialize the raid system
load_modules

if [ -n "$root_evms" ] ; then

	create_evms_save_table() {
	    local tblfile=$1
	    local num=0
	    shift
	
	    rm -f $tblfile
	    
	    dmdevs=$(dmsetup info -c --noheadings -o name)
	    for d in $dmdevs ; do
		# Check if device exists (ie is a partition)
		if [ ! -e /dev/$d ] ; then
		    unset d
		fi
		# Filter out devices used by EVMS region
		for e in $*; do
		    if [ "$d" = "$e" ] ; then
			unset d
		    fi
		done
		# Create temp table
		if [ "$d" ] ; then
		    echo $(( num * 100 )) 100 linear /dev/$d 0 >> $tblfile
		    num=$(( num + 1 ))
		fi
	    done
	    echo $num
	}
	
	/sbin/evms_activate

	evmsnum=$(create_evms_save_table /tmp/evms_save_table)
	if [ $evmsnum -gt 0 ] ; then
	    /sbin/dmsetup remove_all
	    /sbin/dmsetup create evms_save < /tmp/evms_save_table
	    /sbin/evms_activate
	    /sbin/dmsetup remove evms_save
	fi
fi

