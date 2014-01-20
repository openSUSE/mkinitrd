#!/bin/bash
#
#%stage: device
#%depends: network

ibft_set_iface() {
    local iface

    if test -d "$ibft_nic/device/net" ; then
	for iface in $ibft_nic/device/net/*/addr_len; do
	    break
        done
    else
	for iface in $ibft_nic/device/*/*/addr_len; do
            break
	done
    fi
    iface=${iface%/*}
    iface=${iface##*/}
    if test -n "$iface"; then
	interface=$iface
	drvlink="$drvlink $(get_network_module $interface)"
	if [ ! "$nettype" -a -e $ibft_nic/dhcp ]; then
	    nettype=dhcp
	    read ibft_dhcp < $ibft_nic/dhcp
	    [ "$ibft_dhcp" = "0.0.0.0" ] && nettype=static
	else
	    nettype=static
	fi
    fi
}

ibft_nic=/sys/firmware/ibft/ethernet0
ibft_nic2=/sys/firmware/ibft/ethernet1
ibft_hostname=$(hostname)

if [ "$root_iscsi" = 1 -a -d $ibft_nic ]; then
    ibft_available=1
    ibft_set_iface
fi
save_var ibft_available
save_var ibft_hostname
save_var ibft_nic
