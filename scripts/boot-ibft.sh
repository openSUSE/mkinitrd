#!/bin/bash
#%stage: device
#%modules: iscsi_ibft
#%if: "$ibft_available"
#: ${ibft_nic:=/sys/firmware/ibft/ethernet0}
#
###### iBFT network configuration
##
## This script obtains network configuration parameters
## from the iBFT, if available

load_modules

ibft_get_att() {
    if [ -f $ibft_nic/$1 ]; then
	cat $ibft_nic/$1
    else
	echo ""
    fi
}

ibft_get_ethdev() {
    (cd $ibft_nic/device/net; ls -d eth* 2>/dev/null)
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

if [ -d $ibft_nic ]; then
    if [ -s $ibft_nic/dhcp ]; then
	nettype='dhcp'
    else
	nettype='static'
    fi
    ip="$(ibft_get_att ip-addr)::$(ibft_get_att gateway):$(ibft_get_att subnet-mask):$ibft_hostname:$(ibft_get_ethdev):$nettype"
    interface=$(ibft_get_ethdev)
    macaddress=$(ibft_get_att mac)
    InitiatorName=$(ibft_get_initiatorname)
fi
