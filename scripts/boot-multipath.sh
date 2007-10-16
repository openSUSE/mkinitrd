#!/bin/bash
#%stage: block
#%depends: dm
#%provides: dmroot
#%programs: /sbin/multipath /sbin/mpath_id /sbin/mpath_prio_*
#%if: "$root_mpath"
#%modules: dm-multipath dm-emc dm-hp_sw dm-rdac
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

