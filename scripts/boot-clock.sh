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
    	  > /dev/shm/warpclock
    esac
elif test -e /etc/adjtime -a -e /etc/localtime
then
    while read line
    do
	if test "$line" = LOCAL
	then
	    /bin/warpclock
	    > /dev/shm/warpclock
	fi
    done < /etc/adjtime
fi
