#!/bin/bash
#
#%stage: boot
#%depends: start
#%modules: rtc_cmos
#%provides: rtc
#%programs: usleep
#%if: -n "$(modprobe -C /dev/null --set-version $kernel_version --ignore-install --show-depends rtc_cmos 2>/dev/null)"
#%dontshow

if test ! -e /sys/class/rtc/rtc0
then
    load_modules
    typeset -i rtccount=300
    while ((rtccount-- > 0)) ; do
	test -e /sys/class/rtc/rtc0 && break
	usleep 10000
    done
    unset rtccount
fi
