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
	if [ -h "bin/$busyfile" ]; then
	    # don't process symlinks
    	    continue
	elif [ -e "bin/$busyfile" ]; then
	    verbose "[BUSYBOX] replacing $DIR/$busyfile"
	    rm -f bin/$busyfile
	elif [ -e "sbin/$busyfile" ]; then
	    DIR=sbin
	    rm -f sbin/$busyfile
	    verbose "[BUSYBOX] replacing $DIR/$busyfile"
	fi
	# we have to remove the copied program files from the
	# internal list so we only get shared libs that are
	# actually used
	declare -i binc
	for ((binc=0 ; $binc<${#initrd_bins[@]} ; binc++)); do
	${A##*/}
	    if [ "${initrd_bins[$binc]##*/}}" = "$busyfile" ]; then
	    	initrd_bins[$binc]=''
	    fi
	done
	ln -s ../bin/busybox "$DIR/$busyfile"
      done
    fi
fi
