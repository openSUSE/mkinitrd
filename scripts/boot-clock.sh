#!/bin/bash
#
#%stage: boot
#%depends: start rtc udev
#%provides: clock
#%dontshow

if test -e /etc/sysconfig/clock -a -e /etc/localtime
then
    . /etc/sysconfig/clock
    case "$HWCLOCK" in
    *-l*) /bin/warpclock
    esac
fi
