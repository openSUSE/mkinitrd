#!/bin/bash
#
#%stage: device
#%depends: iscsi nfs lldpad fcoe
#%param_D: "Run dhcp on the specified interface." interface @dhcp_interfaces
#%param_I: "Configure the specified interface statically." interface @static_interfaces
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
        ifname=$(ip route | sed -n 's/default .* dev \([[:alnum:]]*\) *.*/\1/p')
        if [ $(ps -A -o cmd= | sed -n "/.*dhcp.*$ifname.*/p" | wc --lines) -eq 2 ] ; then
            BOOTPROTO=dhcp
        else
            BOOTPROTO=static
        fi
    fi

    # if the interface is a bridge, then try to use the underlying interface
    # if it is the only non-virtual interface (not tap or vif)
    if [ -d "/sys/class/net/$ifname/bridge" -a \
            -d "/sys/class/net/$ifname/brif" ] ; then

        local ifname2 res count=0
        for ifname2 in "/sys/class/net/$ifname/brif"/*; do
            case "$(readlink -f "$ifname2")" in
            /sys/devices/virtual/*)
                continue
            esac
            res=${ifname2##*/}
            count=$[count+1]
        done

        if [ "$count" -ne 1 ] ; then
            echo >&2 "WARNING: $ifname is a bridge with more than one interfaces"
            echo >&2 "         behind the bridge. Please call mkinitrd with a"
            echo >&2 "         device name manually (-D or -I)."
        else
            ifname="$res"
        fi
    fi

    echo $ifname/$BOOTPROTO
}

get_network_module()
{
    local interface=$1 drvlink

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

    echo "$drvlink"
}

for addfeature in $ADDITIONAL_FEATURES; do
    if [ "$addfeature" = "network" ]; then
        if test -z "$interface$static_interfaces$dhcp_interfaces"; then
            interface=default
        fi
    fi
    if [ "$addfeature" = "ifup" ] ; then
	nettype=ifup
	interface=
        dhcp_interfaces=
        static_interfaces=
    fi
done

ip=
# get the default interface if requested by some script
if [ "$interface" = "default" ]; then
    interface=
    if test -z "$static_interfaces$dhcp_interfaces"; then
        ifspec=$(get_default_interface)
        case "${ifspec##*/}" in
            dhcp*|ibft*)
                dhcp_interfaces=${ifspec%%/*}
                ;;
            *)
                static_interfaces=${ifspec%%/*}
                ;;
        esac
    fi
fi

for iface in $interface; do
    cfg=/etc/sysconfig/network/ifcfg-$iface
    BOOTPROTO=
    if test -e "$cfg"; then
        eval $(grep BOOTPROTO "$cfg")
    fi
    case "$BOOTPROTO" in
    dhcp*|ibft*)
        dhcp_interfaces="$dhcp_interfaces $iface"
        ;;
    *)
        static_interfaces="$static_interfaces $iface"
    esac
done
interface=

if [ "$create_monster_initrd" ]; then
    # include all network card modules
    for i in $(find $root_dir/lib/modules/$kernel_version/kernel/drivers/net -name "*.ko" -o -name "*.ko.gz"); do
        i="${i%*.gz}"
        i=${i%*.ko}
        drvlink="$drvlink ${i##*/}"
    done
fi

static=true
seen_interfaces=
for iface in $static_interfaces -- $dhcp_interfaces; do
    if test "x$iface" = "x--"; then
        static=false
        continue
    fi
    # resolve default interface if requested via the commandline -D or -I
    # option
    if test "$iface" = "default"; then
        iface=$(get_default_interface)
        iface=${iface%%/*}
    fi
    case " $seen_interfaces " in
    *" $iface "*)
        continue
    esac
    seen_interfaces="$seen_interfaces $iface"
    if [ -d /sys/class/net/$iface/device ] ; then
        drvlink="$drvlink $(get_network_module $iface)"
        read macaddress < /sys/class/net/$iface/address
        if $static; then
            static_macaddresses="$static_macaddresses $iface:$macaddress"
        else
            dhcp_macaddresses="$dhcp_macaddresses $iface:$macaddress"
        fi
    elif [ -d /sys/class/net/$iface/bonding ] ; then
        verbose "[NETWORK]\tConfigure bonding for $iface"
        bonding_module=bonding
        drvlink="$drvlink bonding"
        config=
        for param in mode miimon arp_interval arp_ip_target; do
            config="${config:+$config~}$param:$(< /sys/class/net/$iface/bonding/$param)"
        done
        slaves=$(< /sys/class/net/$iface/bonding/slaves)
        for interf in $slaves; do
            # include hardware modules for the slaves
            mod=$(get_network_module $interf)
            drvlink="$drvlink $mod"
        done
        read bonding_$iface <<<"slaves:$slaves~$config"
        save_var bonding_$iface
        if $static; then
            static_macaddresses="$static_macaddresses BONDING:$iface"
        else
            dhcp_macaddresses="$dhcp_macaddresses BONDING:$iface"
        fi
    fi
done

# Copy ifcfg settings
mkdir -p $tmp_mnt/etc/sysconfig
cp -rp /etc/sysconfig/network $tmp_mnt/etc/sysconfig
if [ "$nettype" = "ifup" ] ; then
    for i in /etc/sysconfig/network/ifcfg-*; do
	interface=${i##*/ifcfg-}
	if [ -d /sys/class/net/$interface/device ] ; then
	    mod=$(get_network_module $interface)
	    drvlink="$drvlink $mod"
	    verbose "[NETWORK]\tifup: $interface"
	fi
    done
    interface=
fi

# Copy the /etc/resolv.conf when the IP is static
if test -n "$static_interfaces"; then
    verbose "[NETWORK]\tUsing /etc/resolv.conf from the system in the initrd"
    cp /etc/resolv.conf $tmp_mnt/etc
fi

# Copy netcfg files (bnc#468090, bnc#714945)
for file in /etc/{hosts,protocols,services,netconfig}; do
  test -f "$file" && cp "$file" $tmp_mnt/etc
done

# Get static IP configuration if requested
for iface in $static_interfaces; do
    static_ips="$static_ips $(get_ip_config $iface)"
done

mkdir -p $tmp_mnt/var/lib/dhcpcd
mkdir -p $tmp_mnt/var/run

cp_bin /lib/mkinitrd/bin/ipconfig $tmp_mnt/bin/ipconfig
if [ -f /etc/udev/rules.d/70-persistent-net.rules ] ; then
    cp /etc/udev/rules.d/70-persistent-net.rules $tmp_mnt/etc/udev/rules.d
fi
for f in /{lib,etc}/udev/rules.d/77-network.rules; do
    if ! test -e "$f"; then
        continue
    fi
    cp --parents "$f" $tmp_mnt/
done

test -n "$static_interfaces" && verbose "[NETWORK]\tstatic: $static_interfaces"
test -n "$dhcp_interfaces" && verbose "[NETWORK]\tdynamic: $dhcp_interfaces"

save_var nettype
save_var static_macaddresses
save_var static_ips
save_var dhcp_macaddresses
save_var drvlink
save_var bonding_module

# vim:sw=4:et
