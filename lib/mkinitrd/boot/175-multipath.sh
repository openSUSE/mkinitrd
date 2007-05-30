#!/bin/bash
#%requires: kpartx
#%programs: /sbin/multipath /sbin/mpath_id /sbin/mpath_prio_*
#%if: "$root_mpath"
#%modules: dm-multipath
#
##### Multipath
##
## If the root device can be accessed using multiple device paths, 
## this initializes and waits for them
##
## Command line parameters
## -----------------------
##
## root_mpath=1		use multipath
## mpath_status=off	do not use multipath
## 

load_modules

# wait for all multipath partitions to appear
mpath_check_for_partitions() {
    local num=0

    for link in $(ls /dev/disk/by-id/scsi-*); do
	[ -L "$link" ] || continue
	node=$(ls -l $link | sed -ne 's/.*\.\.\/\(.*\)/\1/p')
	if [ "$link" = "${link%%-part*}" ] ; then
	    dev=$link
	    case "$node" in
		dm-*)
		    dev=$link;;
		*)
		    dev=none;;
	    esac
	else
	    if [ "$link" != "${link#$dev}" ] ; then
		case "$node" in
		    dm-*)
			: this node is okay
			;;
		    *)
			num=$((num + 1))
			;;
		esac
	    fi
	fi
    done
    return $num
}
mpath_wait_for_partitions() {
  local timeout=$udev_timeout
  local retval=1
  while [ $timeout -gt 0 ] ; do
    if mpath_check_for_partitions; then
      retval=0
      break;
    fi
    /sbin/udevsettle --timeout=$udev_timeout
    sleep 1
    echo -n "."
    timeout=$(( $timeout - 1 ))
  done
  return $retval
}
# check for multipath parameter in /proc/cmdline
mpath_status=$(get_param multipath)

mpath_list=$(sed -n '/multipath/p' /proc/modules)
if [ -z "$mpath_list" ] ; then
  mpath_status=off
fi
if [ "$mpath_status" != "off" ] ; then
  # Rescan for multipath
  echo -n "Setup multipath devices: "
  /sbin/multipath -v0
  /sbin/udevsettle --timeout=$udev_timeout
  # On larger setups udev might time out prematurely
  /sbin/dmsetup ls --target multipath --exec "/sbin/kpartx -a -p -part"
  /sbin/udevsettle --timeout=$udev_timeout
  echo 'ok.'
fi

