#!/lib/klibc/bin/sh
# $Id: mkinitramfs-kinit.sh,v 1.15 2004/05/31 18:31:06 olh Exp $
# vim: syntax=sh
# set -x

# do not export PATH or bad things will happen once init runs
PATH=/sbin:/usr/sbin:/bin:/usr/bin:/lib/klibc/bin
echo " running ($$:$#) $0" "$@"

if [ "$$" != 1 ] ; then
	echo $0 must run as /init process
	sleep 3
	exit 42
fi

# create all mem devices, ash cant live without /dev/null
for i in \
/sys/class/mem/*/dev \
; do
	if [ ! -f $i ] ; then continue ; fi
	echo -n "."
	DEVPATH=${i##/sys}
	ACTION=add DEVPATH=${DEVPATH%/dev} /sbin/udev mem
done
exec < /dev/console > /dev/console 2>&1
echo

. /etc/udev/udev.conf


mkdir -p "$udev_root"
# allow bind mount, to not lose events
mount -t tmpfs -o size=3% initramdevs "$udev_root"
mkdir "$udev_root/shm"
mkdir "$udev_root/pts"

for i in /proc /sys /tmp /root ; do 
	if [ ! -d "$i" ] ; then mkdir "$i" ; fi
done

if [ ! -f /proc/cpuinfo ] ; then mount -t proc proc /proc ; fi
if [ ! -d /sys/class ] ; then mount -t sysfs sysfs /sys ; fi

# load drivers for the root filesystem, if needed
if [ -x /load_modules.sh ] ; then
	PATH=$PATH /load_modules.sh
fi
#
# create all remaining device nodes
echo -n "creating device nodes .."
/sbin/udevstart
echo .

# workaround chicken/egg bug in mdadm and raidautorun
# they do the ioctl on the not yet existing device node...
mknod -m 660 /dev/md0 b 9 0
mknod -m 660 /dev/md1 b 9 1
mknod -m 660 /dev/md2 b 9 2

if [ -x /load_md.sh ] ; then
	PATH=$PATH /load_md.sh
fi

#
# sh
#
debug=
init=
root=
rootfstype=
read cmdline < /proc/cmdline
for i in $cmdline ; do
	oifs="$IFS"
	opt=
	case "$i" in
		init=*) 
			init="`echo $i | sed -e 's@^init=@@'`"
			;;
		ip=*:*) ipinterface=false;;
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
			if [ -z "$root" ] ; then
				root=/dev/nfs
			fi
			;;
		# iscsi
		DiscoveryAddress=*)
			DiscoveryAddress="`echo $i | sed -e 's@^DiscoveryAddress=@@'`"
			;;
		InitiatorName=*)
			InitiatorName="`echo $i | sed -e 's@^InitiatorName=@@'`"
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
		debug)
			#debug=true
			;;
	esac
	IFS="$oifs"
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
	if [ ! -z "$DiscoveryAddress" -a ! -z "$InitiatorName" ] ; then
		root=iscsi
	else
		echo root= not provided on kernel cmdline
		echo root=discover not yet implemented
		sleep 5
		echo 42 > /proc/sys/kernel/panic
		exit 1
	fi
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

failed=0
case "$root" in
	iscsi)
		ipconfig $ipinterface
		echo updating iscsi config
		echo "Continuous=no" >> /etc/iscsi.conf
		echo "ImmediateData=no" >> /etc/iscsi.conf
		echo "$target" >> /etc/iscsi.conf
		echo "$initiatorname" >> /etc/initiatorname.iscsi
		echo "Starting iSCSI"
		iscsid
		sleep 5
		echo "mount $FSTYPE $mountopt $root /root"
		if [ ! -b "$root" ] ; then echo "$root missing ... "; sleep 1 ; fi
		sleep 1
		mount $FSTYPE $mountopt "$root" /root || failed=1
	;;
	/dev/nfs|*:/*)
	echo "root looks like nfs ..."
	ipconfig $ipinterface
	case "$root" in
		*:/*)
		nfsserver="$root"
	esac
	if [ -z "$nfsserver" ] ; then
		. /tmp/net-"$ipinterface".conf
		nfsserver="$ROOTSERVER:$ROOTPATH"
	fi
	echo "nfsmount $nfsoptions $nfsserver"
	sleep 3
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
	echo "looking for init ..."
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

mount -o bind "$udev_root" "/root$udev_root"
chmod 0755 "/root$udev_root"
ln -s /proc/self/fd "/root$udev_root/fd"
mknod /dev/fb0 c 29 0
mknod /dev/fb1 c 29 1
mknod /dev/ppp c 108 0
#
# sh
#
# debugging aid
if [ -x /root/sbin/hotplug-beta -a -f /proc/sys/kernel/hotplug ] ; then
	echo /sbin/hotplug-beta > /proc/sys/kernel/hotplug
fi
#
if [ -x /vendor_init.sh ] ; then
	/vendor_init.sh
fi

# ready to leave
umount /proc
umount /sys
cd /root

INIT="$init"
export INIT
if [ "$debug" = "true" ] ; then
echo starting shell because debug was found in /proc/cmdline
PATH=$PATH sh
fi
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
