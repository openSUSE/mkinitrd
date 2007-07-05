#!/bin/bash
#
#%stage: device
#
if [ "$(echo $blockdev | grep dasd)" ]; then
	root_dasd=1
fi

save_var root_dasd

if [ "$root_dasd" ]; then
    for dasd in $blockdev; do
    	update_blockdev $dasd
	if [ "$blockdriver" = "dasd" ]; then
	    for dir in /sys/block/dasd*; do
	    	if [ "$(cat $dir/dev)" = "$blockmajor:$blockminor" ]; then
	    	    dir_found=1
	    	    break
	    	fi
	    done
	    # dir should contain the correct directory now
	    if [ ! "$dir_found" ]; then
	    	error 1 "dasd device $dasd not found in sysfs!"
	    fi
	    case $dasd in
	    	*dasda)	;;		# first dasd device is ok
	    	/dev/disk/by*)	;;	# persistent device names are ok
	    	*) error 1 "DASD devices necessary for booting have to be defined using persistent device names or be dasda." ;;
	    esac
	    
	    if [ -d "$dir" ] && [ -d ${dir}/device ]; then
		dir=$(cd -P $dir/device; echo $PWD)
		ccw=${dir##*/}
		echo "ACTION==\"add\", SUBSYSTEM==\"ccw\", DEVPATH==\"*/$ccw\", RUN+=\"/bin/bash -c 'echo 1 > /sys\$env{DEVPATH}/online'\"" > ./etc/udev/rules.d/55-dasd-${ccw}.rules
		if [ -r "$dir/discipline" ]; then
		    read type < $dir/discipline
		    
		    case $type in
			ECKD)
			    discipline=0
			    ;;
			FBA)
			    discipline=1
			    ;;
			DIAG)
			    discipline=2
			    ;;
			*)
			    ;;
		    esac
		fi
	    fi
	fi
    done
fi
