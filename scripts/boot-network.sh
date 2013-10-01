#!/bin/bash
#%stage: device
#%depends: ibft
#%programs: dhcpcd
#%programs: ifup
#%programs: ip
# tools used by ifup
#%programs: awk
#%programs: grep
#%programs: logger
#%programs: touch
# dhcpcd reqires the af_packet module
#%modules: af_packet $bonding_module
#%udevmodules: $drvlink
#%if: "$interface" -o "$dhcp" -o "$ip" -o "$nfsaddrs" -o "$drvlink"
#
##### network initialization
##
## This script initializes networking
##
## Command line parameters
## -----------------------
##
## dhcp=<device>                                                                                                        if set runs dhcp on the given device (no dhcp if device is "off")
## ip=$ipaddr:$peeraddr:$gwaddr:$netmask:$hostname:$iface:$autoconf     defines the ip configuration to use
## nfsaddrs                                                                                                                     an alias for "ip"
## net_delay=<seconds>                                                  additional delay after the network is set up
##

# load the modules before detecting which device we are going to use
load_modules

configure_static()
{
    local ip=$1

    ipconfig $ip
    # dhcp information emulation
    if [ "${ip:0:1}" = "[" ]; then
        # address in brackets (necessary for IPv6)
        ip="${ip:1}"
        IPADDR="${ip%%]:*}"
        ip="${ip#*]:}"
    else
        IPADDR="${ip%%:*}"
        ip="${ip#*:}"
    fi # first entry => peeraddr
    PEERADDR="${ip%%:*}"
    ip="${ip#*:}" # first entry => gwaddr
    GATEWAY="${ip%%:*}"
    ip="${ip#*:}" # first entry => netmask
    NETMASK="${ip%%:*}"
    ip="${ip#*:}" # first entry => hostname
    HOSTNAME="${ip%%:*}"
    ip="${ip#*:}" # first entry => iface
    INTERFACE="${ip%%:*}"
    echo 'hosts: files dns' >> /etc/nsswitch.conf
}

configure_dynamic()
{
    local interface=$1

    echo "running dhcpcd on interface $interface"
    dhcpcd -R -Y -N -t 120 $interface
    if [ -s /var/lib/dhcpcd/dhcpcd-$interface.info ] ; then
        . /var/lib/dhcpcd/dhcpcd-$interface.info
    else
        emergency "no response from dhcp server"
    fi
    [ -e "/var/run/dhcpcd-$interface.pid" ] && kill -9 $(cat /var/run/dhcpcd-$interface.pid)
    if [ -n "$DNS" ]; then
        oifs="$IFS"
        IFS=","
        for ns in $DNS ; do
            echo "nameserver $ns" >> /etc/resolv.conf
        done
        IFS="$oifs"
        if [ -n "$DOMAIN" ]; then
                echo "search $DOMAIN" >> /etc/resolv.conf
        fi
        echo 'hosts: files dns' >> /etc/nsswitch.conf
    elif [ -n "$DNSSERVERS" ]; then
        oifs="$IFS"
        IFS=" "
        for ns in $DNSSERVERS ; do
            echo "nameserver $ns" >> /etc/resolv.conf
        done
        IFS="$oifs"
        if [ -n "$DNSDOMAIN" ]; then
                echo "search $DNSDOMAIN" >> /etc/resolv.conf
        fi
        echo 'hosts: files dns' >> /etc/nsswitch.conf
    fi
}

# configure_bonding iface "slaves:eth0 eth1~miimon:..."
configure_bonding()
{
    local iface=$1 config=$2 param value
    local slaves slave mode miimon arp_interval arp_ip_target

    if test ! -d /sys/class/net/$iface; then
        echo "+$iface" >/sys/class/net/bonding_masters
    fi
    ip link set $iface down

    local saveifs="$IFS"
    local IFS='~'
    set -- $config
    for param; do
        : "$param"
        value=${param#*:}
        case "$param" in
        slaves:*)
            slaves=(${value// /\~})
            ;;
        *)
            if test -n "$value"; then
                echo "$value" >/sys/class/net/$iface/bonding/${param%%:*}
            fi
        esac
    done
    IFS="$saveifs"

    ip link set $iface up
    for slave in "${slaves[@]}"; do
        echo "+$slave" > /sys/class/net/$iface/bonding/slaves
    done
}


# macaddr2if eth0:00:00:de:ad:be:ef
macaddr2if()
{
    local macaddress=${1#*:} fallback=${1%%:*} tmpmac dev

    for dev in /sys/class/net/* ; do
        # skip files that are no directories
        if ! [ -d $dev ] ; then
            continue
        fi

        read tmpmac < $dev/address
        if [ "$tmpmac" == "$macaddress" ] ; then
            echo ${dev##*/}
            return
        fi
    done
    echo "$fallback"
}

i=0
static_ips=($static_ips)
static=true
static_interfaces=""
for macaddr in $static_macaddresses -- $dhcp_macaddresses; do
    if test "x$macaddr" = "x--"; then
        static=false
        continue
    fi
    case "$macaddr" in
    BONDING:*)
        iface=${macaddr#*:}
        var=bonding_$iface
        configure_bonding "$iface" "${!var}"
        ;;
    *)
        iface=$(macaddr2if "$macaddr")
    esac

    if $static; then
        ip="${static_ips[i++]}"

        # the interface name in the ip config string can differ from the actual
        # one, replace it
        nettype=${ip##*:}
        ip=${ip%:*}
        tmpip=${ip%:*}
        ip="${tmpip}:${iface}:${nettype}"
        static_interfaces="$iface $static_interfaces"

        configure_static "$ip"
    else
        # Skip this interface if it was already configured static
        case " $static_interfaces " in
        *\ $iface\ *) continue;;
        *) ;;
        esac
        configure_dynamic "$iface"
    fi
done

# static ip config
if [ "$nettype" = "ifup" ] ; then
    for i in /etc/sysconfig/network/ifcfg-* ; do
	interface=${i##*/ifcfg-}
	[ -d /sys/class/net/$interface/device ] || continue
	[ "$interface" = "lo" ] && continue
	ifup $interface
    done
fi

if [ "0$(get_param net_delay)" -gt 0 ]; then
        echo "[NETWORK] sleeping for $net_delay seconds."
        sleep "$(get_param net_delay)"
fi

# vim: et:sw=4:sts=4
