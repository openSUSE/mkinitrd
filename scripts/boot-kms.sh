#!/bin/bash
#
#%stage: boot
#
#%depends: start
#
#%modules: $kms_modules
#
#%if: "$kms_modules"

[ -e /proc/cmdline ] || return
for i in `cat /proc/cmdline`
do
    case $i in
	nomodeset)
	    # for udev
	    if [ "$gfx_modules" ]
	    then
		for j in $gfx_modules
		do
		    add_module_param $j modeset=0
		done
	    fi
	    dont_load_modules; return
	    ;;
    esac
done

