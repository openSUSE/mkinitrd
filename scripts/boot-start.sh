#!/bin/bash
#
#%stage: boot
#%depends: devfunctions
#%programs: /bin/bash umount test mount mknod mkdir ln date sleep echo cat /bin/sed /sbin/insmod /sbin/modprobe kill /sbin/killall5 /sbin/halt /sbin/reboot /sbin/showconsole cp /sbin/pidof mv chmod rm true ls /lib/mkinitrd/bin/*
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
## [module].param=value sets a kernel module parameter
##

export PATH=/sbin:/usr/sbin:/bin:/usr/bin

die() {
    umount /proc
    umount /sys
    if [ "$devpts" = "yes" ]; then
        umount -t devpts /dev/pts
    fi
    umount /dev
    exit $1
}

mount -t proc  proc  /proc
mount -t sysfs sysfs /sys
mount -t tmpfs -o mode=0755 udev /dev

mknod -m 0666 /dev/tty     c 5 0
mknod -m 0600 /dev/console c 5 1
mknod -m 0666 /dev/ptmx    c 5 2

exec < /dev/console > /dev/console 2>&1

mknod -m 0666 /dev/null c 1 3
mknod -m 0600 /dev/kmsg c 1 11
mknod -m 0660 /dev/snapshot c 10 231
mknod -m 0666 /dev/random c 1 8
mknod -m 0644 /dev/urandom c 1 9
mkdir -m 0755 /dev/pts
mkdir -m 1777 /dev/shm
ln -s /proc/self/fd /dev/fd
ln -s fd/0 /dev/stdin
ln -s fd/1 /dev/stdout
ln -s fd/2 /dev/stderr

# export variables automatically so we see them in the rescue shell
[ "$debug" ] && set -a

tty_driver=

# kernel commandline parsing
for o in $(cat /proc/cmdline); do
    key="${o%%=*}"
    key="${key//-/_}"
    if [ "${key%.*}" != "${key}" ]; then # module parameter
        add_module_param "${key%.*}" "${o#*.}"
    else
        # environment variable
        # set local variables too, in case somehow the kernel does not do this correctly
        value="${o#*=}"
        value=${value:=1}
        eval cmd_$key="${value}"
        eval $key="${value}" 2> /dev/null
    fi
done

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

echo "" > /proc/sys/kernel/hotplug

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
