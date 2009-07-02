#!/bin/bash
#
#%stage: boot
#%param_s: "Add splash animation and bootscreen to initrd." size splash
#
# architecture dependend changes from default:
if [ "$splash" = "offbydefault" ]; then
    case "$(uname -m)" in
        i?86|x86_64)
	    splash="auto"
	    ;;
	*)
	    splash="off"
	    ;;
    esac
fi

# handle splash screen
case "$splash" in
off)
    splashsizes= ;;
auto)
    unset ${!splash_size_*}
    modes=
    for file in $root_dir/{etc/lilo.conf,boot/grub/menu.lst,proc/cmdline}; do
	[ -e $file ] || continue
 	modes="$modes $(sed -rn  '/^[[:blank:]]*[^#]/{ s/^.*vga[[:blank:]]*=[[:blank:]]*([[:digit:]]+|0[xX][[:xdigit:]]+)/\1/p; }' $file)"
    done

    for mode in $modes; do
	case $(($mode)) in  # $((...)) : Convert 0xFOO to decimal
	785|786) splash_size_640x480=1 ;;
	788|789) splash_size_800x600=1 ;;
	791|792) splash_size_1024x768=1 ;;
	794|795) splash_size_1280x1024=1 ;;
	*)       vgahex=$(printf 0x%04x "$(($mode))")
		 if [ -x /usr/sbin/hwinfo ] ; then
		     size=$(/usr/sbin/hwinfo --framebuffer | \
			 sed -ne 's/^.*Mode '$vgahex': \([^ ]\+\) .*$/\1/p' \
			 2>/dev/null)
		     eval splash_size_$size=1
		 fi ;;
        esac
    done
    # Get current modes from fb
    for fb in /sys/class/graphics/fb* ; do
	if [ -d $fb ] && [ -f $fb/virtual_size ] ; then
	    size=$(sed -ne 's/,/x/p' $fb/virtual_size)
	    eval splash_size_$size=1
	fi
    done
    splashsizes="$(for x in ${!splash_size_*}; do
			echo ${x#splash_size_}
		   done)"
    unset ${!splash_size_*}
    ;;
*)
    splashsizes=$splash ;;
esac


splash_bin=
[ -x /sbin/splash.bin ] && splash_bin=/sbin/splash.bin
[ -x /bin/splash ] && splash_bin=/bin/splash
splash_image=
if [ -n "$splashsizes" -a -n "$splash_bin" ]; then
    if [ -f /etc/sysconfig/bootsplash ]; then
	. /etc/sysconfig/bootsplash
    fi

    themes_dir=
    if [ -d "$root_dir/etc/bootsplash/themes" ]; then
	themes_dir="$root_dir/etc/bootsplash/themes"
    elif [ -d "$root_dir/usr/share/splash/themes" ]; then
	themes_dir="$root_dir/usr/share/splash/themes"
    fi

    no_splash=
    [ "$SPLASH" = "no" ] && no_splash=1
    case ${kernel_version##*-} in
	kdump|um|xen*)
	    no_splash=1
	    ;;
    esac

    echo -ne "Bootsplash:\t"
    if [ -n "$no_splash" ]; then
	echo "No bootsplash for kernel flavor ${kernel_version##*-}"
    else
	if [ -n "$themes_dir" ] && \
	    [ -d "$themes_dir/$THEME" -o -L "$themes_dir/$THEME" ]; then
	    for size in $splashsizes; do
		bootsplash_picture="$themes_dir/$THEME/images/bootsplash-$size.jpg"
		cfgname="$themes_dir/$THEME/config/bootsplash-$size.cfg"
		if [ ! -r $cfgname ] ; then
		    echo "disabled for resolution $size"
		elif [ ! -r $bootsplash_picture ] ; then
		    echo "no image for resolution $size"
		else
		    echo -n "${splash_image:+, }$THEME ($size)"
		    splash_image="$splash_image $cfgname"
		fi
	    done
	    echo
	else
	    echo "no theme selected"
	fi
    fi
fi

# Include bootsplash image
for image in $splash_image; do
    $splash_bin -s -f $image >> $tmp_mnt/bootsplash
done

save_var no_splash
save_var splash
