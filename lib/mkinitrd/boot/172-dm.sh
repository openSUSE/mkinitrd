#!/bin/bash
#%requires: nfs
#%modules: $dm_modules dm-mod dm-snapshot
#%programs: /sbin/dmsetup
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

echo -n "Waiting for /dev/mapper/control to appear: "
for i in 1 2 3 4 5; do
    [ -e /dev/mapper/control ] && break
    sleep 1
    echo -n "."
done
if [ -e /dev/mapper/control ]; then
    echo " ok"
else
    echo " failed"
fi

