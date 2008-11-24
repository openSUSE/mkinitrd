#!/bin/bash
#%stage: device
#%programs: /sbin/dhcpcd /sbin/ip
# dhcpcd reqires the af_packet module
#%modules: af_packet 
#%udevmodules: $drvlink
#%if: "$interface" -o "$dhcp" -o "$ip" -o "$nfsaddrs"
#
##### network initialization
##
## This script initializes networking
##
## Command line parameters
## -----------------------
##
## dhcp=<device>													if set runs dhcp on the given device (no dhcp if device is "off")
## ip=$ipaddr:$peeraddr:$gwaddr:$netmask:$hostname:$iface:$autoconf	defines the ip configuration to use
## nfsaddrs															an alias for "ip"
## 

# load the modules before detecting which device we are going to use
load_modules

# mac address based config
if [ "$macaddress" ] ; then
    nettype=${ip##*:}
    ip=${ip%:*}
    interface=${ip##*:}
    tmpip=${ip%:*}
    for dev in /sys/class/net/* ; do
      read tmpmac < $dev/address
      if [ "$tmpmac" == "$macaddress" ] ; then
        interface=${dev##*/}
        echo "using interface $interface"
      fi
    done
    ip="${tmpip}:${interface}:${nettype}"
fi

if [ "$nfsaddrs" -a ! "$(get_param ip)" ]; then 
	ip=$nfsaddrs
fi

if [ "$ip" -a ! "$(echo $ip | sed '/:/P;d')" ]; then
	echo "[NETWORK] using dhcp on $interface based on ip=$ip"
	nettype=dhcp
elif [ "${ip##*:}" = dhcp ]; then
	nettype=dhcp
	newinterface="${ip%*:dhcp}"
	newinterface="${newinterface##*:}"
	[ "$newinterface" != dhcp -a "$newinterface" ] && interface="$newinterface"
	echo "[NETWORK] using dhcp on $interface based on ip=$ip"
fi

if [ "$(get_param dhcp)" -a "$(get_param dhcp)" != "off" ]; then
	echo "[NETWORK] using dhcp based on dhcp=$dhcp"
	interface=$(get_param dhcp)
	nettype=dhcp
fi

[ "$(get_param dhcp)" = "off" ] && nettype=static

if [ "$ip" -a "$nettype" != "dhcp" ]; then
	echo "[NETWORK] using static config based on ip=$ip"
	nettype=static
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
      echo 'hosts: dns' > /etc/nsswitch.conf
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
      echo 'hosts: dns' > /etc/nsswitch.conf
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
fi

