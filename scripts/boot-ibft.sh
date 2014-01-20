#!/bin/bash
#%stage: device
#%modules: iscsi_ibft ipv6
#%programs: cat
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

setup_ibft_nic() {
    local nic=$1

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
    ip="$ipaddr::$(ibft_get_att gateway $nic):$netmask:$ibft_hostname:$(ibft_get_ethdev):$nettype"
    interface=$(ibft_get_ethdev)
    macaddress=$(ibft_get_att mac $nic)
    if [ $nettype = 'dhcp' ] ; then
	dhcp_macaddresses="$interface:$macaddress $dhcp_macaddresses"
    else
	static_macaddresses="$interface:$macaddress $static_macaddresses"
	static_ips="$ip $static_ips"
    fi
}

if [ -d $ibft_nic ]; then
    setup_ibft_nic $ibft_nic
    InitiatorName=$(ibft_get_initiatorname)
    [ -d $ibft_nic2 ] && setup_ibft_nic $ibft_nic2
fi
