#!/bin/bash
#
#%stage: setup
#%depends: start
#

# Default udev timeout is 30 seconds
udev_timeout=30

mkdir -p $tmp_mnt/etc/udev/rules.d
mkdir -p $tmp_mnt/usr/lib/udev/rules.d
mkdir -p $tmp_mnt/usr/lib/systemd
mkdir -p $tmp_mnt/lib
ln -sfn ../usr/lib/udev $tmp_mnt/lib/udev

# copy helper
for script in /usr/lib/udev/* /lib/udev/* /sbin/*_id ; do
    if [ ! -d "$script" ] && [ -x "$script" ] ; then
        cp_bin $script ${tmp_mnt}${script}
    elif [ -f "$script" ] ; then
        cp -pL $script ${tmp_mnt}${script}
    fi
done

# copy needed rules
for rule in \
    05-udev-early.rules \
    50-udev-default.rules \
    50-firmware.rules \
    59-dasd.rules \
    60-persistent-storage.rules \
    60-persistent-input.rules \
    61-msft.rules \
    62-dm_linear.rules \
    64-device-mapper.rules \
    64-md-raid.rules \
    79-kms.rules \
    80-drivers.rules; do
    if [ -f /usr/lib/udev/rules.d/$rule ]; then
        cp /usr/lib/udev/rules.d/$rule $tmp_mnt/usr/lib/udev/rules.d
    elif [ -f /lib/udev/rules.d/$rule ]; then
        cp /lib/udev/rules.d/$rule $tmp_mnt/lib/udev/rules.d
    elif [ -f /etc/udev/rules.d/$rule ]; then
        cp /etc/udev/rules.d/$rule $tmp_mnt/etc/udev/rules.d
    fi
done

save_var udev_timeout
