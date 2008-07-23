#!/bin/bash
#
#%stage: filesystem
#%provides: resume
#%depends: dump
#
#%if: -x /usr/sbin/resume -o -x /sbin/resume
#%programs: /sbin/resume
#
##### software suspend resume
##
## If software suspending has suspended the computer before
## this script tries to resume it to the state
## it was before.
## This is the implementation using a userspace program.
##
## Command line parameters
## -----------------------
##
## resume		the device to resume from
## 

[ "$noresume" ] && resume_mode=off

# Verify manual resume mode
if [ "$resume_mode" != "off" -a -n "$resumedev" ]; then
    if [ -x /sbin/resume -o -w /sys/power/resume ]; then
	echo "Trying manual resume from $resumedev"
	resume_mode=1
    else
	resumedev=
    fi
fi

discover_user_resume() {
    local resume devn major minor
    if [ ! -f /sys/power/resume ] ; then
	return
    fi
    if [ ! -e "$resumedev" ] ; then
	echo "resume device $resumedev not found (ignoring)"
	return
    fi
    # Waits for the resume device to appear
    if [ "$resume_mode" != "off" ]; then
	if [ -x /sbin/resume ]; then
	    echo "Invoking userspace resume from $resumedev"
	    read procsplash < /proc/splash
	    case "$procsplash" in
	    *silent*)
		# if the version of "resume" is not new enough, "-P" will fail.
		/sbin/resume -P 'splash = y' $resumedev || /sbin/resume $resumedev
		;;
	    *)
		/sbin/resume -P 'splash = n' $resumedev || /sbin/resume $resumedev
		;;
	    esac
	fi
    fi
}

wait_for_events
# Check for a resume device
discover_user_resume

unset discover_user_resume
