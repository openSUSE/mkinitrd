#!/bin/bash
#
#%stage: volumemanager
#
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
	evms_cmd="q:r"

	while read a b c d; do
	    if [ "$a $b" = "Region Name:" ]; then
		evms_reg="$evms_reg $c"
	    fi
	done < <( echo "$evms_cmd" | /sbin/evms -s )
    fi

    : EVMS Regions $evms_reg

    for reg in $evms_reg; do
	evms_cmd="q:c,r=$reg"
	
	while read a b c d; do
	    if [ "$a $b" = "Container Name:" ]; then
		if [ "$evms_cont" ] ; then
		    for cont in $evms_cont; do
			if [ "$c" = "$cont" ] ; then
			    unset c
			    break;
			fi
		    done
		    if [ "$c" ] ; then
			evms_cont="$evms_cont $c"
		    fi
		else
		    evms_cont="$c"
		fi
	    fi
	done < <(echo "$evms_cmd" | /sbin/evms -s )
    done

    : EVMS Containers $evms_cont

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
	done < <(echo "$evms_cmd" | /sbin/evms -s )
    done

    : EVMS Segments $evms_seg

    for seg in $evms_seg; do
	evms_cmd="q:d,s=$seg"

	while read a b c d; do
	    if [ "$a $b $c" = "Logical Disk Name:" ]; then
		if [ "$evms_dsk" ] ; then
		    for dsk in $evms_dsk; do
			if [ "$d" = "$dsk" ] ; then
			    unset d
			    break;
			fi
		    done
		    if [ "$d" ] ; then
			evms_dsk="$evms_dsk $d"
		    fi
		else
		    evms_dsk="$d"
		fi
	    fi
	done < <(echo "$evms_cmd" | /sbin/evms -s )
    done


    echo "$evms_seg"
}

create_evms_save_table() {
    local tblfile=/tmp/evms_save_table
    local tblname=$1
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

    if [ $num -gt 0 ] ; then
	echo dmsetup create $tblname < $tblfile
	echo rm -f $tblfile
    fi
}

# get information about the current blockdev

evms_blockdev=

for bd in $blockdev; do
    update_blockdev $bd
    realrootdev=
    # EVMS always runs on device-mapper so no device-mapper device means no evms
    if [ "$blockdriver" = device-mapper ]; then
	# Check whether we are using EVMS
	if [ -x /sbin/evms ] && [ "${blockdev#/dev/evms}" != "$blockdev" ]; then
	    region=$(echo "q:r" | /sbin/evms -s -b | grep -B 2 "Minor: $blockminor" | sed -n 's@Region Name: \(.\)@\1@p')
	    if [ "$region" ] ; then
		volume=$(echo "q:v,r=$region" | /sbin/evms -s -b | sed -n 's@Volume Name: \(.*\)@\1@p')
		if [ -e "$volume" ] ; then
		    root_evms=1
		    realrootdev=$volume
		    # blockdev="$(get_evms_devices $blockdev)"
		    evms_blockdev="$evms_blockdev $(dm_resolvedeps $blockdev)"
		    [ $? -eq 0 ] || return 1
		fi
	    fi
	fi
    fi
    if [ ! "$realrootdev" ]; then # no evms
    	evms_blockdev="$evms_blockdev $bd"
    fi
done

blockdev="$evms_blockdev"

# copy files
if [ -n "$root_evms" ] ; then
        tmp_root_dm=1 # evms needs dm
        mkdir -p $tmp_mnt/mnt
        cp -a /etc/evms.conf $tmp_mnt/etc
        evms_lib=
        case "$(uname -m)" in
            alpha|ia64)
                evms_lib="/lib/evms"
                ;;
            *)
		# this was $tmp_mnt/sbin/evms_activate before but we copy the binaries after 
		# the raid setup now so this is not possible anymore
                case "`LANG=C LC_ALL=C file -b /sbin/evms_activate | awk '/^ELF ..-bit/ { print $2 }'`" in
                    32-bit) evms_lib="/lib/evms" ;;
                    64-bit) evms_lib="/lib64/evms" ;;
                esac
                ;;
        esac
        if [ "$evms_lib" ] ; then
            mkdir -p ${tmp_mnt}${evms_lib}
            SD=$(ls -A $evms_lib | tail -n 1)
            (cd ${tmp_mnt}${evms_lib} && mkdir -p $SD)
            cp_bin $evms_lib/$SD/* ${tmp_mnt}${evms_lib}/$SD
            rm -f ${tmp_mnt}${evms_lib}/*/*{ext2,jfs,ogfs,reiser,swap,xfs}*so
        else
            oops 7 "No EVMS modules found"
        fi
fi

save_var root_evms

