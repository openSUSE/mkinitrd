#!/bin/bash
#
#%stage: device
#
if [ "$(echo $block_modules | grep zfcp)" ]; then
	root_zfcp=1
fi

save_var root_zfcp

if [ "$root_zfcp" ]; then
    for dev in $blockdev; do
    	update_blockdev $dev
	if [ "$blockdriver" = "sd" ]; then
	    for dir in /sys/block/sd*; do
	    	if [ "$(cat $dir/dev)" = "$blockmajor:$blockminor" ]; then
	    	    dir_found=1
	    	    break
	    	fi
	    done
	    # dir should contain the correct directory now
	    if [ ! "$dir_found" ]; then
	    	error 1 "zfcp device $dev not found in sysfs!"
	    fi
	    if [ -d "$dir" ] && [ -d ${dir}/device ]; then
		dir=$(cd -P $dir/device; echo $PWD)
		scsinum=${dir##*/}
		# Configure the controller
		host=${scsinum%%:*}
		ccwdir=$(cd -P /sys/class/scsi_host/host$host/device; cd ..; echo $PWD)
		ccw=${ccwdir##*/}
		if [ ! -f ./etc/udev/rules.d/56-zfcp-${ccw}.rules ] ; then
		    echo "ACTION==\"add\", SUBSYSTEM==\"ccw\", DEVPATH==\"*/$ccw\", RUN+=\"/bin/bash -c 'echo 1 > /sys/\$env{DEVPATH}/online'\"" > ./etc/udev/rules.d/56-zfcp-${ccw}.rules
		fi
		# Configure the FC target
		tgtnum=${scsinum%:*}
		tgtdir=$(cd -P /sys/class/fc_transport/target$tgtnum; echo $PWD)
		read wwpn < $tgtdir/port_name
		read lun < $dir/fcp_lun
		echo "ACTION==\"add\", SUBSYSTEM==\"scsi_host\", DEVPATH==\"*/${ccw}/host*\", RUN+=\"/bin/bash -c 'echo $wwpn > /sys/bus/ccw/devices/${ccw}/unit_add'\""  > ./etc/udev/rules.d/57-zfcp-${ccw}:${wwpn}:${lun}.rules
		echo "ACTION==\"add\", SUBSYSTEM==\"scsi_host\", DEVPATH==\"*/${ccw}/host*\", RUN+=\"/bin/bash -c '[ -d /sys/bus/ccw/devices/${ccw}/${wwpn} ] && echo $lun > /sys/bus/ccw/devices/${ccw}/${wwpn}/port_add'\""  >> ./etc/udev/rules.d/57-zfcp-${ccw}:${wwpn}:${lun}.rules
	    fi
	fi
    done
fi
