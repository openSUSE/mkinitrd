#!/bin/bash
#
#%stage: boot
#%depends: devfunctions

#%programs: /lib/mkinitrd/bin/*
#%programs: bash
#%programs: cat
#%programs: date
#%programs: ln
#%programs: mkdir
#%programs: mknod
#%programs: mount
#%programs: showconsole
#%programs: sleep
#%programs: umount
#%programs: sulogin

# tools used by linuxrc/init
#%programs: insmod
#%programs: modprobe
#%programs: sed

# tools used by ipconfig.sh
#%programs: ip
#%programs: sed

#%modules: $RESOLVED_INITRD_MODULES
#%udevmodules: $RESOLVED_INITRD_MODULES_UDEV
#%dontshow
#
##### Initrd initialization
##
## this script initializes the initrd properly, so we have a usable environment thereafter
##
## Command line parameters
## -----------------------
##
## console              the device we should redirect the output to (ttyS0 for serial console)
## linuxrc=trace        activates debugging for the initrd process
## tmpfs_options	tmpfs extra mount options (for /dev)
## [module].param=value sets a kernel module parameter
##

export PATH=/sbin:/usr/sbin:/bin:/usr/bin

die() {
    umount /proc
    umount /sys
    umount /dev/pts
    umount /dev
    exit $1
}

emergency() {
    local plymouth sulogin
    if plymouth=$(type -p plymouth 2> /dev/null) ; then
	$plymouth quit
	$plymouth --wait
    fi
    if test -w /proc/splash ; then
	echo verbose >| /proc/splash
    fi
    cd /
    echo -n "${1+$@} -- "
    if sulogin=$(type -p sulogin 2> /dev/null); then
	echo "exiting to $sulogin"
	PATH=$PATH PS1='$ ' $sulogin /dev/console
    else
	echo "exiting to /bin/sh"
	PATH=$PATH PS1='$ ' /bin/sh -i
    fi
}

mount -t proc proc /proc
mount -t sysfs sysfs /sys
if mount -t devtmpfs -o mode=0755,nr_inodes=0${tmpfs_options:+,$tmpfs_options} devtmpfs /dev; then
    have_devtmpfs=true
else
    have_devtmpfs=false
    mount -t tmpfs -o mode=0755,nr_inodes=0${tmpfs_options:+,$tmpfs_options} udev /dev

    mknod -m 0666 /dev/tty     c 5 0
    mknod -m 0600 /dev/console c 5 1
    mknod -m 0666 /dev/ptmx    c 5 2
    mknod -m 0666 /dev/null c 1 3
    mknod -m 0600 /dev/kmsg c 1 11
    mknod -m 0660 /dev/snapshot c 10 231
    mknod -m 0666 /dev/random c 1 8
    mknod -m 0644 /dev/urandom c 1 9
fi
mkdir -m 1777 /dev/shm
mount -t tmpfs -o mode=1777 tmpfs /dev/shm
mkdir /run
mount -t tmpfs -o mode=0755,nodev,nosuid tmpfs /run
mkdir -m 0755 /dev/pts
mount -t devpts -o mode=0620,gid=5 devpts /dev/pts
ln -s /proc/self/fd /dev/fd
ln -s fd/0 /dev/stdin
ln -s fd/1 /dev/stdout
ln -s fd/2 /dev/stderr

exec < /dev/console > /dev/console 2>&1

# export variables automatically so we see them in the rescue shell
[ "$debug" ] && set -a

# kernel commandline parsing
cmdline=$(cat /proc/cmdline)
pos=0

# stores next character from /proc/cmdline in $c
next_char() {
	c=${cmdline:pos++:1}
	test -n "$c"
}

# stores next var[=value] string from /proc/cmdline in $var
# supports double quotes to some extent
next_var() {
	local c quoted=false

	var=
	# eat leading whitespace
	next_char || return
	while test "$c" = ' ' -o "$c" = $'\t'; do
		next_char || return
	done
	while true; do
		case "$c" in
		' ' | $'\t')
			if $quoted; then
				var="$var$c"
			else
				break
			fi
			;;
		'"')
			if $quoted; then
				quoted=false
			else
				quoted=true
			fi
			;;
		*)
			var="$var$c"
			;;
		esac
		next_char || break
	done
}

while next_var; do
    key="${var%%=*}"
    key="${key//[^a-zA-Z0-9_.]/_}"
    cmd_key="cmd_$key"
    case "$key" in
    *.*)
        # module parameter, ignored
        continue
        ;;
    [^a-zA-Z_]*)
        # starts with a digit - set only the cmd_ variant
        key=
        ;;
    esac
    # set local variables too, in case somehow the kernel does not do this correctly
    value="${var#*=}"
    value=${value:=1}
    read $cmd_key < <(echo "$value")
    if test -n "$key"; then
        read $key < <(echo "$value")
    fi
done
unset next_char next_var c pos cmdline key cmd_key value var

if ! $have_devtmpfs; then
    tty_driver=
    if [ "$console" ]; then
        tty_driver="${tty_driver:+$tty_driver }${console%%,*}"
    fi

    for o in $tty_driver; do
        case "$o" in
            ttyS*) test -e /dev/$o || mknod -m 0660 /dev/$o c 4 64 ;;
            tty*)  test -e /dev/$o || mknod -m 0660 /dev/$o c 4  1 ;;
        esac
    done

    # create the tty device nodes
    tty_driver=$(showconsole -n 2>/dev/null)
    if test -n "$tty_driver" ; then
        major=${tty_driver%% *}
        minor=${tty_driver##* }
        if test $major -eq 4 -a $minor -lt 64 ; then
            tty=/dev/tty$minor
            test -e $tty || mknod -m 0660 $tty c 4 $minor
        fi
        if test $major -eq 4 -a $minor -ge 64 ; then
            tty=/dev/ttyS$((64-$minor))
            test -e $tty || mknod -m 0660 $tty c 4 $minor
        fi
        unset major minor tty
    fi
    unset tty_driver
fi

kernel_cmdline=($@)

case "$build_day" in
        @*) ;;
        *)
                current_day="$(LC_ALL=C date -u '+%Y%m%d')"
                if [ "$current_day" -lt "$build_day" ] ; then
                        echo "your system time is not correct:"
                        LC_ALL=C date -u
                        echo "setting system time to:"
                        LC_ALL=C date -us "$build_day"
                        sleep 3
                        export SYSTEM_TIME_INCORRECT=$current_day
                fi
        ;;
esac

if [ "$linuxrc" = "trace" ]; then
    echo -n "cmdline: "
    for arg in $@; do
        echo -n "$arg "
    done
    echo ""
    set -x
    debug_linuxrc=1
fi

if [ "$sysrq" ] && [ "$sysrq" != "no" ] ; then
    echo 1 > /proc/sys/kernel/sysrq
    case "$sysrq" in
        0|1|2|3|4|5|6|7|8|9)
            echo $sysrq > /proc/sysrq-trigger
            ;;
    esac
fi
