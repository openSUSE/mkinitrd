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
    if [ -z "$ifname" ]; then
      for cfg in /etc/sysconfig/network/ifcfg-*; do
	if [ $(basename $cfg) = "ifcfg-lo" ] ; then
	    continue;
	fi
	eval $(grep STARTMODE $cfg)
	if [ "$STARTMODE" = "nfsroot" ]; then
	    cfgname=$(basename $cfg)
	    ifname=${cfg#*/ifcfg-}
	    eval $(grep BOOTPROTO $cfg)
	    break;
	fi
      done
    fi
    # No nfsroot interface description
    if [ -z "$ifname" ]; then
    	ifname=$(/sbin/ip route | sed -n 's/default .* dev \([[:alnum:]]*\) */\1/p')
	if [ $(ps -A -o cmd= | sed -n '/.*dhcp.*$ifname.*/p' | wc --lines) -eq 2 ] ; then
	    BOOTPROTO=dhcp
	else
	    BOOTPROTO=static
	fi
    fi 
    echo $ifname/$BOOTPROTO
}

if [ -z "$interface" ] ; then
    for addfeature in $ADDITIONAL_FEATURES; do
	if [ "$addfeature" = "network" ]; then
	    interface=default
	fi
    done
fi

interface=${interface#/dev/}
[ "$param_D" ] && nettype=dhcp
[ "$param_I" ] && nettype=static

# get the default interface if requested
if [ "$interface" = "default" ]; then
    ifspec=$(get_default_interface)
    interface=${ifspec%%/*}
    if [ "${ifspec##*/}" = "dhcp" ] ; then
	nettype=dhcp
    else
	nettype=static
    fi
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
	# xen network driver registers as 'vif'
	if [ "$drvlink" == "vif" ] ; then
	    drvlink=xennet
	fi
        read macaddress < /sys/class/net/$interface/address
    fi
fi

# Get static IP configuration if requested
if [ "$interface" -a "$nettype" = "static" ] ; then
    ip=$(get_ip_config $interface)
fi

mkdir -p $tmp_mnt/var/lib/dhcpcd
mkdir -p $tmp_mnt/var/run

cp_bin $root_dir/lib/mkinitrd/bin/ipconfig.sh $tmp_mnt/bin/ipconfig

[ "$interface" ] && verbose "[NETWORK]\t$interface ($nettype)"

save_var nettype
save_var ip
save_var interface
save_var macaddress
save_var drvlink
