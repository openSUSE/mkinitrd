#!/bin/bash
#
#%stage: device
#%depends: iscsi nfs
#%param_D: "Run dhcp on the specified interface." interface interface
#%param_I: "Configure the specified interface statically." interface interface
#
# Calculate the netmask for a given prefix
calc_netmask() {
    local prefix=$1
    local netmask

    netmask=
    num=0
    while (( $prefix > 8 )) ; do
	if (( $num > 0 )) ; then
	    netmask="${netmask}.255"
	else
	    netmask="255"
	fi
	prefix=$(($prefix - 8))
	num=$(($num + 1))
    done
    if (( $prefix > 0 )) ; then
	mask=$(( 0xFF00 >> $prefix ))
    else
	mask=0
    fi
    netmask="${netmask}.$(( $mask & 0xFF ))"
    num=$(($num + 1))
    while (( $num < 4 )) ; do
	netmask="${netmask}.0"
	num=$(($num + 1))
    done
    echo $netmask
}

# Get the interface information for ipconfig
get_ip_config() {
    local iface
    local iplink
    local iproute

    iface=$1
    iplink=$(ip addr show dev $iface | grep "inet ")

    set -- $iplink
    if [ "$1" == "inet" ]; then
	shift

	ipaddr=${1%%/*}
	prefix=${1##*/}
	shift 
	if [ "$1" == "peer" ] ; then
	    shift
	    peeraddr=${1%%/*}
	    prefix=${1##*/}
	fi
	netmask=$(calc_netmask $prefix)
	bcast=$3
    fi
    iproute=$(ip route list dev $iface | grep default)
    if [ $? -eq 0 ]; then
	set -- $iproute
	gwaddr=$3
    fi
    hostname=$(hostname)
    echo "$ipaddr:$peeraddr:$gwaddr:$netmask:$hostname:$iface:none"
}  

get_default_interface() {
    local ifname
    local inffile="/etc/install.inf"

    # Determine the default network interface
    if [ -f $inffile ] ; then
	# Get info from install.inf during installation
	BOOTPROTO=$(sed -ne 's/NetConfig: \(.*\)/\1/p' $inffile)
	ifname=$(sed -ne 's/Netdevice: \(.*\)/\1/p' $inffile)
	macaddress=$(sed -ne 's/HWAddr: \(.*\)/\1/p' /etc/install.inf)
	if [ "$macaddress" ] ; then
	    for dev in /sys/class/net/* ; do
		read tmpmac < $dev/address
		if [ "$tmpmac" == "$macaddress" ] ; then
		    ifname=${dev##*/}
		fi
	    done
	fi
    fi
    # interface description not found in install.inf
    if [ ! "$ifname" ]; then
      for cfg in /etc/sysconfig/network/ifcfg-*; do
	if [ $(basename $cfg) = "ifcfg-lo" ] ; then
	    continue;
	fi
	eval $(grep STARTMODE $cfg)
	if [ "$STARTMODE" = "nfsroot" ]; then
	    cfgname=$(basename $cfg)
	    ifname=$(getcfg-interface ${cfg#*/ifcfg-})
	    eval $(grep BOOTPROTO $cfg)
	    break;
	fi
      done
    fi
    if [ ! "$ifname" ]; then
    	ifname="$(/sbin/route -n | egrep "^0.0.0.0")"
    	ifname=${ifname##* }
    fi 
    echo $ifname/$BOOTPROTO
}

interface=${interface#/dev/}
[ "$param_D" ] && use_dhcp=1
[ "$param_I" ] && use_ipconfig=1

# get the default interface if requested
if [ "$interface" = "default" ]; then
	ifspec=$(get_default_interface)
	interface=${ifspec%%/*}
fi

if [ "$create_monster_initrd" ]; then
    # include all network card modules
    for i in $(find $root_dir/lib/modules/$kernel_version/kernel/drivers/net -name "*.ko"); do
	i=${i%*.ko}
	drvlink="$drvlink ${i##*/}"
    done
fi

if [ -n "$interface" ] ; then
    # Pull in network module
    if [ -d /sys/class/net/$interface/device ] ; then
    	ifpath=$(cd -P /sys/class/net/$interface/device; echo $PWD)
        if [ -f /sys/class/net/$interface/device/modalias ] ; then
            read drvlink  < /sys/class/net/$interface/device/modalias
        elif [ -f /sys/class/net/$interface/device/driver/module ] ; then
            drvlink=$(cd /sys/class/net/$interface/device/driver; readlink module)
        else
            drvlink=$(cd /sys/class/net/$interface/device; readlink driver)
        fi
        drvlink=${drvlink##*/}
        read macaddress < /sys/class/net/$interface/address
    fi
    
    # type of eth device (eth, ctc, ...)
    iftype="$(echo $interface | sed 's/^\([a-z|!]*\)[0-9]*$/\1/')"
    
	if [ ! -e "$configfile" ]; then
	    # try mac based config file
		configfile="/etc/sysconfig/network/ifcfg-$iftype-id-$macaddress"
	fi
	if [ ! -e "$configfile" ]; then
		# try bus based config file
		busid=$(basename $ifpath)
		
		case "$ifpath" in
			*pci*)
				bustype=pci
				;;
			*css*)
				bustype=ccw
				;;
			*cu*)
				bustype=ccw
				;;
		esac
		configfile="/etc/sysconfig/network/ifcfg-$iftype-bus-$bustype-$busid"
	fi
	if [ ! -e "$configfile" ]; then
	    # try id based config file
		configfile="/etc/sysconfig/network/ifcfg-$interface"
	fi
	[ -e "$configfile" ] && . $configfile
	
	if [ "$BOOTPROTO" = "dhcp" -a ! "$use_ipconfig" ]; then
		use_dhcp=1
		use_ipconfig=
	elif [ ! "$use_dhcp" ]; then
		use_dhcp=
		use_ipconfig=1
	fi
    ip=$(get_ip_config $interface)
fi

mkdir -p $tmp_mnt/var/lib/dhcpcd
mkdir -p $tmp_mnt/var/run

cp_bin $root_dir/lib/mkinitrd/bin/ipconfig.sh $tmp_mnt/bin/ipconfig

[ "$use_ipconfig" ] && nettype=static
[ "$use_dhcp" ] && nettype=dhcp
[ "$interface" ] && verbose "[NETWORK]\t$interface ($nettype)"

save_var use_ipconfig
save_var use_dhcp
save_var ip
save_var interface
save_var macaddress
save_var drvlink
