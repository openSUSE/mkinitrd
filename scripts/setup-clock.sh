#!/bin/bash
#%stage: boot
#%depends: prepare

if test -e /etc/localtime
then
    mkdir -m 0755 -p $tmp_mnt/etc
    cp -p /etc/localtime $tmp_mnt/etc/
fi
if test -e /usr/share/zoneinfo/UTC
then
    mkdir -m 0755 -p $tmp_mnt/usr/share/zoneinfo
    cp -p /usr/share/zoneinfo/UTC $tmp_mnt/usr/share/zoneinfo/
fi
if test -e /etc/sysconfig/clock
then
    . /etc/sysconfig/clock
    mkdir -m 0755 -p $tmp_mnt/etc/sysconfig
    echo HWCLOCK='"'"$HWCLOCK"'"' > $tmp_mnt/etc/sysconfig/clock
fi
