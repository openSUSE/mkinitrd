#!/lib/klibc/bin/sh
# $Id: mkinitramfs-kinit.sh,v 1.29 2004/10/27 14:48:52 olh Exp $
# vim: syntax=sh
# set -x

if [ "$$" != 1 ] ; then
	echo $0 must run as /init process
	sleep 3
	exit 42
fi

# use the device node provided by the kernel
exec < /dev/console > /dev/console 2>&1
# do not export PATH or bad things will happen once init runs
PATH=/sbin:/usr/sbin:/bin:/usr/bin:/lib/klibc/bin
echo " running ($$:$#) $0" "$@"
#
. /etc/udev/udev.conf
for i in "$udev_root" /proc /sys /tmp /root ; do 
	if [ ! -d "$i" ] ; then mkdir "$i" ; fi
done
# allow bind mount, to not lose events
mount -t tmpfs -o size=3% initramdevs "$udev_root"
mkdir "$udev_root/shm"
mkdir "$udev_root/pts"
chmod 0755 "$udev_root"

if [ ! -f /proc/cpuinfo ] ; then mount -t proc proc /proc ; fi
if [ ! -d /sys/class ] ; then mount -t sysfs sysfs /sys ; fi
ln -s /proc/self/fd "$udev_root/fd"
ln -s fd/0 "$udev_root/stdin"
ln -s fd/1 "$udev_root/stdout"
ln -s fd/2 "$udev_root/stderr"

# create all mem devices, ash cant live without /dev/null
for i in \
/sys/class/mem/*/dev \
; do
	if [ ! -f $i ] ; then continue ; fi
	DEVPATH=${i##/sys}
	UDEV_NO_SLEEP=yes ACTION=add DEVPATH=${DEVPATH%/dev} /sbin/udev mem
done

if [ ! -x /sbin/hotplug ] ; then
rm -f /sbin/hotplug
ln -s /sbin/udev /sbin/hotplug
fi

# load drivers for the root filesystem, if needed
if [ -x /load_modules.sh ] ; then
	PATH=$PATH /load_modules.sh
fi

#
# sh
#
init=
root=
rootfstype=
read cmdline < /proc/cmdline
for i in $cmdline ; do
	opt=
	case "$i" in
		init=*) 
			init="`echo $i | sed -e 's@^init=@@'`"
			;;
		ip=*)
			ipinterface="`echo $i | sed -e 's@^ip=@@'`"
			;;
		root=*) 
			root="`echo $i | sed -e 's@^root=@@'`"
			;;
		rootfstype=*)
			rootfstype="`echo $i | sed -e 's@^rootfstype=@@'`"
			;;
		nfsroot=*)
			nfsroot="`echo $i | sed -e 's@^nfsroot=@@'`"
			nfsoptions="`echo $i | sed -e 's@\(^[^,]\+,\)\(.*\)@-o \2@p;d'`"
			nfsserver="`echo $nfsroot | sed -e 's@\(^[^:]\+:[^,]\+\)\(,.*\)\?@\1@p;d'`"
			root=/dev/nfs
			;;
		# iscsi
		DiscoveryAddress=*)
			DiscoveryAddress=$i
			;;
		InitiatorName=*)
			InitiatorName=$i
			;;
		#
		rw)
			readwrite=true
			readonly=false
			;;
		ro)
			readwrite=false
			readonly=true
			;;
	esac
done

if [ -z "$readonly" ] ; then
	mountopt="-o ro"
else
	if [ "$readonly" = "true" ] ; then
		mountopt="ro"
	else
		mountopt="rw"
	fi
	if [ -z "$nfsoptions" ] ; then
		mountopt="-o $mountopt"
	else
		nfsoptions="$nfsoptions,$mountopt"
	fi
fi

if [ -z "$root" ] ; then
	echo root= not provided on kernel cmdline
	echo root=discover not yet implemented
	sleep 5
	echo 42 > /proc/sys/kernel/panic
	exit 1
fi

while read dev type ; do
	case "$fstype" in
	selinuxfs)
	if [ -x /sbin/load_policy -a -f /etc/security/selinux/policy.15 ] ; then
		echo -n "Loading SELinux policy	"
		mkdir /selinux
		if mount -n -t selinuxfs none /selinux >/dev/null 2>/dev/null ; then
		  /sbin/load_policy /etc/security/selinux/policy.15
		  umount /selinux
		  echo "successful"
		else
		  echo "skipped"
		fi
		rmdir /selinux
		break
	fi
	;;
	*) ;;
	esac
done < /proc/filesystems

# establish iSCSI sessions
if [ ! -z "$DiscoveryAddress" -a ! -z "$InitiatorName" ] ; then
	ipconfig $ipinterface
	echo updating iscsi config
	echo "Continuous=no" >> /etc/iscsi.conf
	echo "ImmediateData=no" >> /etc/iscsi.conf
	echo "$DiscoveryAddress" >> /etc/iscsi.conf
	echo "$InitiatorName" >> /etc/initiatorname.iscsi
	echo "Starting iSCSI"
	iscsid
	sleep 5
fi

#
# create all remaining device nodes
echo -n "creating device nodes ."
UDEV_NO_SLEEP=yes /sbin/udevstart
echo -n .

# workaround chicken/egg bug in mdadm and raidautorun
# they do the ioctl on the not yet existing device node...
for i in 0 1 2 3 4 5 6 7 8 9 \
	10 11 12 13 14 15 16 17 18 19 \
	20 21 22 23 24 25 26 27 28 29 \
	30 31 \
; do
mknod -m 660 /dev/md$i b 9 $i
done
if [ ! -e /dev/isdninfo ] ; then
mknod -m 400 /dev/isdninfo c 45 255
fi
if [ ! -e /dev/fb0 ] ; then
mknod -m 660 /dev/fb0 c 29 0
mknod -m 660 /dev/fb1 c 29 1
fi
if [ ! -e /dev/ppp ] ; then
mknod -m 644 /dev/ppp c 108 0
fi
echo .

if [ -x /load_md.sh ] ; then
	PATH=$PATH /load_md.sh
fi

failed=0
case "$root" in
	/dev/nfs|*:/*)
	echo "root looks like nfs ..."
	mkdir -p /dev/nfsroot/
	ipconfig $ipinterface
	cp -av /tmp/net-*.conf /dev/nfsroot/
	case "$root" in
		*:/*)
		nfsserver="$root"
		;;
	esac
	for i in /tmp/net-*.conf ; do
		if [ ! -f $i ] ; then continue ; fi
		. $i
		break
	done
	if [ -z "$nfsserver" ] ; then
		nfsserver="$ROOTSERVER:$ROOTPATH"
	fi
	if [ ! -z "$HOSTNAME" ] ; then
		echo "setting hostname to $HOSTNAME"
		echo "$HOSTNAME" > /proc/sys/kernel/hostname
	fi
	echo "nfsmount $nfsoptions $nfsserver"
	nfsmount $nfsoptions $nfsserver /root || failed=1
	;;
	*:*)
	root="`echo $root | sed -e 's@^0*\(\(0:\|[^0]\+:.*\)\)@\1@;s@:0*\(\(0\|[^0]\+\)\)@:\1@'`"
	for i in \
	/sys/block/*/dev \
	/sys/block/*/*/dev \
	; do
		read j < $i
		if [ "$j" = "$root" ] ; then
			echo -n "found $root in $i; udev says: "
			dev="`echo $i | sed -e 's@^/sys\|/dev$@@g'`"
			udevinfo -q name -p "$dev"
			root="$udev_root`udevinfo -q name -p $dev 2>&1`"
			echo "root is now: $root"
			break
		fi
	done
	if [ ! -z "$rootfstype" ] ; then
		FSTYPE="-t $rootfstype"
	fi
	if [ -x /sbin/fsck ] ; then
		echo "running filesystem check on $root"
		fsck $root || exit 42
	fi
	echo "mount $FSTYPE $mountopt $root"
	if [ ! -b "$root" ] ; then echo "$root missing ... "; sleep 1 ; fi
	sleep 1
	mount $FSTYPE $mountopt "$root" /root || failed=1
	;;
	*)
		case "$root" in
			UUID=*)
			eval $root
			root="-U $UUID"
			;;
			LABEL=*)
			eval $root
			root="-L $LABEL"
			;;
			*)
			if [ ! -b "$root" ] ; then
				echo "waiting for block device node: $root"
				for i in 24 23 22 21 20 19 18 17 16 15 14 13 12 11 10 9 8 7 6 5 4 3 2 1 ; do
					if [ -b "$root" ] ; then break ; fi
					echo -n .
					# $i mal werden wir noch wach ...
					sleep 3
				done
				echo
			fi
			;;
		esac
		if [ ! -z "$rootfstype" ] ; then
			FSTYPE="-t $rootfstype"
		fi
		if [ -x /sbin/fsck ] ; then
			echo "running filesystem check on $root"
			fsck $root || exit 42
		fi
		echo "mount $FSTYPE $mountopt $root"
		mount $FSTYPE $mountopt $root /root || failed=1
	;;
esac
#
if [ "$failed" = 1 ] ; then
echo unable to mount root filesystem on $root
sleep 5
echo 42 > /proc/sys/kernel/panic
exit 42
fi

#
# look for an init binary on the root filesystem
if [ -z "$init" ] ; then
	echo -n "looking for init ... "
	for i in /sbin/init /etc/init /bin/init /bin/sh ; do
		if [ ! -f "/root$i" ] ; then continue ; fi
		init="$i"
		echo "found $i"
		break
	done
fi
#
if [ -z "$init" ] ; then
	echo "No init found.  Try passing init= option to kernel."
	echo 42 > /proc/sys/kernel/panic
	exit 42
fi

/lib/klibc/bin/mount -o move "$udev_root" "/root$udev_root"
if [ -x /root/sbin/MAKEDEV ] ; then
	ln -s /sbin/MAKEDEV "/root$udev_root/MAKEDEV"
fi
#
# sh
#
# debugging aid
if [ -x /root/sbin/hotplug-beta -a -f /proc/sys/kernel/hotplug ] ; then
	echo /sbin/hotplug-beta > /proc/sys/kernel/hotplug
fi
#
INIT="$init"
export INIT
if [ "$debug" = "true" ] ; then
echo starting shell because debug=true was found in /proc/cmdline
PATH=$PATH sh
fi
#
if [ -x /vendor_init.sh ] ; then
	/vendor_init.sh
fi

# ready to leave
cd /root
if [ -f etc/mtab ] ; then
	echo fixating mtab...
	mount -o bind /proc/1/mounts etc/mtab
fi
umount /proc
umount /sys

#
# the point of no return!
#
for i in /*
do
	case "$i" in
		/root|/dev|/run_init|/bin|/lib*)
			continue;;
		*)
			rm -rf $i
		;;
	esac
done
rm -rf /bin /lib*
#
exec /run_init "$@" < "./$udev_root/console" > "./$udev_root/console" 2>&1
echo huhu ....
echo 42 > /proc/sys/kernel/panic
exit 42
