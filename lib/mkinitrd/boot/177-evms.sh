#!/bin/bash
#%requires: md
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
	get_evms_devices() {
	    local evms_cmd
	    local evms_reg
	    local evms_cont
	    local evms_seg
	    local evms_dsk
	
	    if [ ! -x /sbin/evms ]; then
		return 1
	    fi
	
	    if [ -n "$1" ]; then
		evms_cmd="q:r,v=$1"
	
		while read a b c d; do
		    if [ "$a $b" = "Region Name:" ]; then
			evms_reg="$evms_reg $c"
		    fi
		done < <( echo "$evms_cmd" | /sbin/evms -s -b )
	    fi
	
	    : EVMS Region: $evms_reg
	
	    for reg in $evms_reg; do
		evms_cmd="q:c,r=$reg"
		
		while read a b c d; do
		    if [ "$a $b" = "Container Name:" ]; then
			evms_cont="$evms_cont $c"
		    fi
		done < <(echo "$evms_cmd" | /sbin/evms -s -b )
	    done
	
	    : EVMS Container: $evms_cont
	
	    for cont in $evms_cont; do
		evms_cmd="q:s,c=$cont"
		
		while read a b c d; do
		    if [ "$a $b" = "Segment Name:" ]; then
			if [ "$evms_seg" ] ; then
			    for seg in $evms_seg; do
				if [ "$c" = "$seg" ] ; then
				    unset c
				    break;
				fi
			    done
			    if [ "$c" ] ; then
				evms_seg="$evms_seg $c"
			    fi
			else
			    evms_seg="$c"
			fi
		    fi
		done < <(echo "$evms_cmd" | /sbin/evms -s -b )
	    done
	
	    echo "$evms_seg"
	}
	
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
	# TODO: what does this do?
	evmsdevs=$(get_evms_devices $rootdev)
	evmsnum=$(create_evms_save_table /tmp/evms_save_table $evmsdevs)
	if [ $evmsnum -gt 0 ] ; then
	    /sbin/dmsetup remove_all
	    /sbin/dmsetup create evms_save < /tmp/evms_save_table
	    /sbin/evms_activate
	    /sbin/dmsetup remove evms_save
	fi
fi

