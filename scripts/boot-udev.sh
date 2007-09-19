#!/bin/bash
#%stage: boot
#%depends: start dm
#%programs: /sbin/udevd /sbin/udevtrigger /sbin/udevsettle udevinfo /sbin/udevcontrol
#%dontshow
#
##### udev initialization
##
## This script starts udev and provides helper functions for later
## functionality based on udev.
##
## Command line parameters
## -----------------------
##

# Waiting for a device to appear
# device node will be created by udev
udev_check_for_device() {
    local root
    local retval=1
    local timeout=$udev_timeout
    root=$1
    if [ -n "$root" ]; then
	echo -n "Waiting for device $root to appear: "
	while [ $timeout -gt 0 ]; do
	    if [ -e $root ]; then
		echo " ok"
		retval=0
		break;
	    fi
	    sleep 1
	    echo -n "."
	    timeout=$(( $timeout - 1 ))
	done
    fi
    return $retval;
}

udev_discover_resume() {
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
	    if [ -x /sbin/resume ]; then
		echo "Invoking userspace resume from $resumedev"
		/sbin/resume $resumedev
	    fi
	    echo "Invoking in-kernel resume from $resumedev"
	    echo "$major:$minor" > /sys/power/resume
	else
	    echo "resume device $resumedev not found (ignoring)"
       fi
    fi
}

udev_discover_dump() {
    local root
    case "$dumpdev" in
	*:*) root= ;;
	/dev/nfs) root= ;;
	/dev/*)	root=${rootdev#/dev/} ;;
    esac
    if [ -z "$root" ]; then
	return 0
    fi
    if udev_check_for_device $dumpdev  ; then
	# Get major:minor number of the device node
	devn=$(devnumber $rootdev)
	major=$(devmajor $devn)
	minor=$(devminor $devn)
    fi
    if [ -n "$devn" ]; then
	echo "rootfs: major=$major minor=$minor" \
	    "devn=$devn"
	echo $devn > /proc/sys/kernel/real-root-dev
	return 0
    else
	return 1
    fi
}

udev_discover_root() {
    local root devn
    case "$rootdev" in
	*:/*) root= ;;
	/dev/nfs) root= ;;
	/dev/*)	root=${rootdev#/dev/} ;;
    esac
    if [ -z "$root" ]; then
	return 0
    fi
    if udev_check_for_device $rootdev  ; then
	# Get major:minor number of the device node
	devn=$(devnumber $rootdev)
    fi
    if [ ! "$devn" ]; then
	if [ ! "$1" ]; then
	    # try the stored fallback device
	    echo \
"Could not find $rootdev.
Want me to fall back to $fallback_rootdev? (Y/n) "
	    read y
	    if [ "$y" = n ]; then
		return 1
	    fi
	    rootdev="$fallback_rootdev"
	    if ! udev_discover_root x ; then
	        return 1
	    fi
    	else
	    return 1
    	fi
    fi
    return 0
}

# Check for debugging
if [ -n "$debug_linuxrc" ]; then
    echo 'udev_log="debug"' >> /etc/udev/udev.conf
else
    echo 'udev_log="error"' >> /etc/udev/udev.conf
fi

# Start udev
echo "Creating device nodes with udev"
/sbin/udevd --daemon
/sbin/udevtrigger
/sbin/udevsettle --timeout=$udev_timeout

unset udev_check_for_device
