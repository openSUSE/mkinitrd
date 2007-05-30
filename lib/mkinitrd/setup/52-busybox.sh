#!/bin/bash

if use_script busybox; then
    if [ ! -x "/usr/bin/busybox" ]; then
	echo "[BUSYBOX] No Busybox executable was found"
    else
      for i in `busybox | grep Curr -A 200 | grep -v "Currently defined f"`; do 
	DIR=bin
	busyfile="${i/,/}"
	# skip programs that do not work properly
	case $busyfile in
	    modprobe|fsck|umount|mount)
		continue
		;;
	esac
	if [ -e "bin/$busyfile" ]; then
	    verbose "[BUSYBOX] replacing $DIR/$busyfile"
	    rm -f bin/$busyfile
	elif [ -e "sbin/$busyfile" ]; then
	    DIR=sbin
	    rm -f sbin/$busyfile
	    verbose "[BUSYBOX] replacing $DIR/$busyfile"
	fi
	ln -s ../bin/busybox "$DIR/$busyfile"
      done
    fi
fi
