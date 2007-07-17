#!/bin/bash
#
#%stage: setup
#%depends: start
# 
mkdir -p $tmp_mnt/etc/udev/rules.d
# Create our own udev.conf
echo "udev_root=\"/dev\"" > $tmp_mnt/etc/udev/udev.conf
echo "udev_rules=\"/etc/udev/rules.d\"" >> $tmp_mnt/etc/udev/udev.conf
# copy needed rules
for rule in 05-udev-early.rules 50-udev-default.rules 59-dasd.rules 60-persistent-storage.rules 64-device-mapper.rules; do
    if [ -f /etc/udev/rules.d/$rule ]; then
	cp /etc/udev/rules.d/$rule $tmp_mnt/etc/udev/rules.d
    fi
done
# include module autoloading
echo 'ACTION=="add", ENV{MODALIAS}=="?*", RUN+="/sbin/modprobe $env{MODALIAS}"' >> ./etc/udev/rules.d/50-udev-default.rules
# copy helper scripts
mkdir -p $tmp_mnt/lib/udev
if [ -f /sbin/vol_id ] ; then
    ln -s ../../sbin/vol_id ${tmp_mnt}/lib/udev/vol_id
fi
for script in /lib/udev/* /sbin/*_id ; do
    if [ -x "$script" ] ; then
	cp_bin $script ${tmp_mnt}${script}
    elif [ -f "$script" ] ; then
	cp -pL $script ${tmp_mnt}${script}
    fi
done

