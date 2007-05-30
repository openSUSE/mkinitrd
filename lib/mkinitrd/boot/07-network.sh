#!/bin/bash
#%requires: usb
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
  for dev in /sys/class/net/* ; do
    read tmpmac < $dev/address
    if [ "$tmpmac" = "$macaddress" ] ; then
      interface=${dev##*/}
      echo "[NETWORK] using interface $interface"
    fi
  done
fi

if [ "$nfsaddrs" -a ! "$(get_param ip)" ]; then 
	ip=$nfsaddrs
fi

if [ "$ip" -a ! "$(echo $ip | grep :)" ]; then
	echo "[NETWORK] using dhcp on $interface based on ip=$ip"
	use_dhcp=1
	use_ipconfig=
elif [ "${ip##*:}" = dhcp ]; then
	use_dhcp=1
	use_ipconfig=
	newinterface="${ip%*:dhcp}"
	newinterface="${newinterface##*:}"
	[ "$newinterface" != dhcp -a "$newinterface" ] && interface="$newinterface"
	echo "[NETWORK] using dhcp on $interface based on ip=$ip"
fi

if [ "$(get_param dhcp)" -a "$(get_param dhcp)" != "off" ]; then
	echo "[NETWORK] using dhcp based on dhcp=$dhcp"
	interface=$(get_param dhcp)
	use_dhcp=1
	use_ipconfig=
fi

[ "$(get_param dhcp)" = "off" ] && use_dhcp=

if [ "$ip" -a ! "$use_dhcp" ]; then
	echo "[NETWORK] using static config based on ip=$ip"
	use_ipconfig=1
fi

# dhcp based ip config
if [ "$use_dhcp" ]; then
  # run dhcp
  if [ "$interface" != "off" ]; then
    # ifconfig lo 127.0.0.1 netmask 255.0.0.0 broadcast 127.255.255.255 up
  
    echo "running dhcpcd on interface $interface"
    dhcpcd -R -Y -N -t 60 $interface
    if [ -s /var/lib/dhcpcd/dhcpcd-$interface.info ] ; then
      . /var/lib/dhcpcd/dhcpcd-$interface.info
    else
      echo "no response from dhcp server."
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
    fi
  fi
  
# static ip config
elif [ -n "$use_ipconfig" ]; then
  # configure interface
  if [ -n "$ip" ]; then
    /bin/ipconfig $ip
    # dhcp information emulation
    IPADDR="${ip%%:*}"
    ip="${ip#*:}" # first entry => peeraddr
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

