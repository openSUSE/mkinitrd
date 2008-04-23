#!/bin/bash
#
#%stage: device
#%depends: network
#
#%modules: netconsole
#%programs: ping arp
#%if: "$interface" -a "$NETCONSOLE"
#
##### network console
##
## This script actives netconsole, which is a method to route dmesg output to a server
##
## Command line parameters
## -----------------------
##
## NETCONSOLE=<server>[:port]	server and port to route the output to
## 

netc_loghost="${NETCONSOLE%:*}"
netc_udpport="${NETCONSOLE#*:}"
if [ "$netc_loghost" = "$netc_udpport" ]; then
	# no colon in NETCONSOLE => no port specified => use default
	netc_udpport="514"	# syslog
fi
ping -c1 $netc_loghost >/dev/null 2>&1
netc_lladdr=$(arp $netc_loghost | while read ip type mac o; do [ "$mac" != "HWaddress" ] && echo $mac; done)
netc_ipaddr=$(arp -n | while read ip type mac o; do [ "$mac" == "$netc_lladdr" ] && echo $ip; done)
echo -e "Netconsole:\tlog to $netc_loghost:$netc_udpport [ $netc_ipaddr / $netc_lladdr ] via $interface"

add_module_param netconsole "netconsole=@/,${netc_udpport}@${netc_ipaddr}/${netc_lladdr}"
