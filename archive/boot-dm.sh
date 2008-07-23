#!/bin/bash
#%stage: boot
#%depends: start
#%modules: $dm_modules dm-mod dm-snapshot
#%programs: /sbin/dmsetup /sbin/blockdev
# dm-crypt dm-zero dm-mirror
#%if: -n "$root_dm"
#
##### Device Mapper
##
## If the root device uses device mapper, this initializes and waits for the control file
##
## Command line parameters
## -----------------------
##
## root_dm=1	use device mapper
## 

load_modules

# because we run before udev we need to create the device node manually
mkdir /dev/mapper
mknod /dev/mapper/control c 10 63
