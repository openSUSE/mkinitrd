#!/bin/bash
#%requires: lvm2
#%programs: /sbin/cryptsetup
#%udevmodules: dm-crypt $cryptmodules
#%if: "$root_luks" -o "$luks"
#
##### LUKS (comfortable disk encryption)
##
## This activates a LUKS encrypted partition.
##
## Command line parameters
## -----------------------
##
## luks			a list of luks devices (e.g. xxx)
## luks_xxx		the luks device (e.g. /dev/sda)
## 

for curluks in $luks; do
	/sbin/cryptsetup luksOpen $(eval echo \$luks_${curluks}) $curluks
done
