#!/bin/bash
#%stage: device
#%programs: /sbin/ip
#%modules: iscsi_ibft ipv6
#%if: "$ibft_available"
#: ${ibft_nic:=/sys/firmware/ibft/ethernet0}
#
###### iBFT network configuration
##
## This script obtains network configuration parameters
## from the iBFT, if available

load_modules

ibft_get_att() {
    local attr=$1 nic=$2

    if [ -f $nic/$attr ]; then
	cat $nic/$attr
    else
	echo ""
    fi
}

ibft_get_ethdev() {
    local iface nic=$1

    if test -d "$nic/device/net" ; then
	for iface in $nic/device/net/*/addr_len; do
	    break
        done
    else
	for iface in $nic/device/*/*/addr_len; do
            break
	done
    fi
    iface=${iface%/*}
    iface=${iface##*/}

    echo "$iface"
}

ibft_get_initiatorname() {
    cat /sys/firmware/ibft/initiator/initiator-name
}

print_par() {
    local val
    while [ $# -gt 0 ]; do
	eval "val=\$$1"
	echo "[IBFT] $1='$val'"
	shift
    done
}

is_hw_offload_interface() { #returns 1 for a offload engine mac address, 0 otherwise
  local transport_info
  transport_info=$(iscsiadm -m host -H $1 -P1 2>/dev/null | grep "Transport:" | sed -e "s/.*Transport: //")
  [ ${#transport_info} -eq 0 ] && return 0   #No transport info should mean no offloading
  [ "$tranport_info" = "tcp" ] && return 0   #The tcp transport is the only non-offload transport
  return 1
}


setup_ibft_nic() {
    local nic=$1
    local eth=$(ibft_get_ethdev $nic)
    local ethmac ibftmac is_offload pcivnd pcidev

    /sbin/ip link set dev $eth up 2>/dev/null

    if [ -s $nic/dhcp ]; then
	nettype='dhcp'
	read ibft_dhcp < $nic/dhcp
	[ "$ibft_dhcp" = "0.0.0.0" ] && nettype='static'
    else
	nettype='static'
    fi
    ipaddr="$(ibft_get_att ip-addr $nic)"
    case "$ipaddr" in
        *:*)
            netmask=64
            ipaddr="[$ipaddr]"
            ;;
        *)
            netmask="$(ibft_get_att subnet-mask $nic)"
            ;;
    esac
    ip="$ipaddr::$(ibft_get_att gateway $nic):$netmask:$ibft_hostname:$eth:$nettype"
    macaddress=$(ibft_get_att mac $nic)

    # bsc#950426 fix for 57810 in hw offload mode with shared eth/offload mac
    read pcivnd < "/sys/class/net/$eth/device/vendor"
    read pcidev < "/sys/class/net/$eth/device/device"
    if [ "$pcivnd:$pcidev" = "0x14e4:0x168e" ]; then  #if 57810
        read ethmac < "/sys/class/net/$eth/address"
        read ibftmac < "$nic/mac"
        is_hw_offload_interface $ibftmac
        is_offload=$?
        if [ "$ethmac" = "$ibftmac"  -a  $is_offload -eq 1 ] ; then
            static_macaddresses="$eth:$macaddress $static_macaddresses"
            ip="0.0.0.0:::255.255.255.255:$ibft_hostname:$eth:$nettype"
            static_ips="$ip $static_ips"
            return
        fi
    fi

    if [ $nettype = 'dhcp' ] ; then
	dhcp_macaddresses="$eth:$macaddress $dhcp_macaddresses"
    else
	static_macaddresses="$eth:$macaddress $static_macaddresses"
	static_ips="$ip $static_ips"
    fi
}

if [ -d $ibft_nic ]; then
    setup_ibft_nic $ibft_nic
    InitiatorName=$(ibft_get_initiatorname)
    [ -d $ibft_nic2 ] && setup_ibft_nic $ibft_nic2
fi
