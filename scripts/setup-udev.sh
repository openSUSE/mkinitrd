#!/bin/bash
#
#%stage: setup
#%depends: start
# 
mkdir -p $tmp_mnt/etc/udev/rules.d
# copy needed rules
for rule in \
    05-udev-early.rules \
    50-udev-default.rules \
    59-dasd.rules \
    60-persistent-storage.rules \
    60-persistent-input.rules \
    62-dm_linear.rules \
    64-device-mapper.rules \
    64-md-raid.rules \
    80-drivers.rules; do
    if [ -f /etc/udev/rules.d/$rule ]; then
	cp /etc/udev/rules.d/$rule $tmp_mnt/etc/udev/rules.d
    fi
done
# copy helper
mkdir -p $tmp_mnt/lib/udev
for script in /lib/udev/* /sbin/*_id ; do
    if [ ! -d "$script" ] && [ -x "$script" ] ; then
	cp_bin $script ${tmp_mnt}${script}
    elif [ -f "$script" ] ; then
	cp -pL $script ${tmp_mnt}${script}
    fi
done

