#!/bin/bash
#
#%stage: filesystem
#%provides: resume
#%depends: resume.userspace
#
#%if: -z "$is_kdump" -a -z "$kdump_kernel"
#
##### software suspend resume
##
## If software suspending has suspended the computer before
## this script tries to resume it to the state
## it was before.
## This implements the pure kernel level resume
##
## Command line parameters
## -----------------------
##
## resume		the device to resume from
## 

[ "$( ( set -u; echo $noresume >/dev/null; echo 1 ) 2>/dev/null )" = "1" ] && resume_mode=off

# Verify manual resume mode
if [ "$resume_mode" != "off" -a -n "$resumedev" ]; then
    if [ -x /sbin/resume -o -w /sys/power/resume ]; then
	echo "Trying manual resume from $resumedev"
	resume_mode=1
    else
	resumedev=
    fi
fi

discover_kernel_resume() {
    local resume devn major minor
    if [ ! -f /sys/power/resume ] ; then
	return
    fi
    if [ -z "$resumedev" ] ; then
	return
    fi
    # Waits for the resume device to appear
    if [ "$resume_mode" != "off" ]; then
	if [ -e $resumedev ] ; then
	    # Try major:minor number of the device node
	    devn=$(devnumber $resumedev)
	    major=$(devmajor $devn)
	    minor=$(devminor $devn)
       fi
       if [ -n "$major" -a -n "$minor" ]; then
	    echo "Invoking in-kernel resume from $resumedev"
	    echo "$major:$minor" > /sys/power/resume
	else
	    echo "resume device $resumedev not found (ignoring)"
       fi
    fi
}
# Wait for udev to settle
/sbin/udevsettle --timeout=$udev_timeout
# Check for a resume device
discover_kernel_resume
