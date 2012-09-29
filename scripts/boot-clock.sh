#!/bin/bash
#
#%stage: boot
#%depends: start rtc udev
#%provides: clock
#%dontshow

if test -e /etc/localtime
then
    if test -e /etc/adjtime
    then
	while read line
	do  if test "$line" = LOCAL
	    then
		warpclock
		> /dev/shm/warpclock
	    fi
	done < /etc/adjtime
    elif test -e /etc/sysconfig/clock
    then
	. /etc/sysconfig/clock
	case "$HWCLOCK" in
	*-l*) warpclock
	   > /dev/shm/warpclock
	esac
    fi
fi
