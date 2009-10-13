#!/bin/bash
#%stage: device
#%depends: ibft
#%programs: /sbin/dhcpcd /sbin/ip
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

# mac address based config
if [ -n "$macaddress" ] ; then
    for dev in /sys/class/net/* ; do
        # skip files that are no directories
        if ! [ -d $dev ] ; then
            continue
        fi

        read tmpmac < $dev/address
        if [ "$tmpmac" == "$macaddress" ] ; then
            interface=${dev##*/}
            echo "[NETWORK] using interface $interface"
        fi
    done

    if [ -n "$ip" ] ; then
        nettype=${ip##*:}
        ip=${ip%:*}
        tmpip=${ip%:*}
        ip="${tmpip}:${interface}:${nettype}"
    fi
fi

if [ -n "$nfsaddrs" -a -z "$(get_param ip)" ]; then
    ip=$nfsaddrs
fi

if [ -n "$ip" -a ! "$(echo $ip | sed '/:/P;d')" ]; then
    echo "[NETWORK] using dhcp on $interface based on ip=$ip"
    nettype=dhcp
elif [ "${ip##*:}" = dhcp ]; then
    nettype=dhcp
    newinterface="${ip%*:dhcp}"
    newinterface="${newinterface##*:}"
    [ "$newinterface" != dhcp -a "$newinterface" ] && interface="$newinterface"
    echo "[NETWORK] using dhcp on $interface based on ip=$ip"
fi

if [ -n "$(get_param dhcp)" -a "$(get_param dhcp)" != "off" ]; then
    echo "[NETWORK] using dhcp based on dhcp=$dhcp"
    interface=$(get_param dhcp)
    nettype=dhcp
fi

[ "$(get_param dhcp)" = "off" ] && nettype=static

if [ -n "$ip" -a "$nettype" != "dhcp" ]; then
    echo "[NETWORK] using static config based on ip=$ip"
    nettype=static
fi

if [[ "$drvlink" = *bonding* ]]; then
    ip link set $interface down
    echo "$miimon" > /sys/class/net/$interface/bonding/miimon
    echo "$mode" > /sys/class/net/$interface/bonding/mode
    ip link set $interface up
    for address in $slave_macaddresses ; do
        for dev in /sys/class/net/* ; do
            if ! [ -d $dev ] ; then
                continue
            fi
            read tmpmac < $dev/address
            if [ "$tmpmac" == "$address" ] ; then
                slave=${dev##*/}
                echo "+$slave" > /sys/class/net/$interface/bonding/slaves
            fi
        done
    done
fi

# dhcp based ip config
if [ "$nettype" = "dhcp" ]; then
    # run dhcp
    if [ "$interface" != "off" ]; then
        echo "running dhcpcd on interface $interface"
        dhcpcd -R -Y -N -t 120 $interface
        if [ -s /var/lib/dhcpcd/dhcpcd-$interface.info ] ; then
            . /var/lib/dhcpcd/dhcpcd-$interface.info
        else
            echo "no response from dhcp server -- exiting to /bin/sh"
            cd /
            PATH=$PATH PS1='$ ' /bin/sh -i
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
            echo 'hosts: files dns' > /etc/nsswitch.conf
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
            echo 'hosts: files dns' > /etc/nsswitch.conf
        fi
    fi

# static ip config
elif [ "$nettype" = "static" ]; then
    # configure interface
    if [ -n "$ip" ]; then
        /bin/ipconfig $ip
        # dhcp information emulation
        IPADDR="${ip%%:*}"
        ip="${ip#*:}" # first entry => peeraddr
        PEERADDR="${ip%%:*}"
        ip="${ip#*:}" # first entry => gwaddr
        GATEWAY="${ip%%:*}"
        ip="${ip#*:}" # first entry => netmask
        NETMASK="${ip%%:*}"
        ip="${ip#*:}" # first entry => hostname
        HOSTNAME="${ip%%:*}"
        ip="${ip#*:}" # first entry => iface
        INTERFACE="${ip%%:*}"
    fi

    echo 'hosts: files dns' > /etc/nsswitch.conf
elif [ "$nettype" = "ifup" ] ; then
    for i in /etc/sysconfig/network/ifcfg-* ; do
	interface=${i##*/ifcfg-}
	[ -d /sys/class/net/$interface/device ] || continue
	[ "$interface" = "lo" ] && continue
	ifup $interface
    done
fi

if [ "$(get_param net_delay)" -a "$(get_param net_delay)" -gt 0 ]; then
        echo "[NETWORK] sleeping for $net_delay seconds."
        sleep "$(get_param net_delay)"
fi
