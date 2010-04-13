#!/bin/bash
#
#%stage: device
#%depends: network

ibft_set_iface() {
    local if=$(cd $ibft_nic/device/net; ls -d eth* 2>/dev/null)
    [ "$if" ] && {
	interface=$if
	if [ ! "$nettype" -a -e $ibft_nic/dhcp ]; then
	    nettype=dhcp
	    read ibft_dhcp < $ibft_nic/dhcp
	    [ "$ibft_dhcp" = "0.0.0.0" ] && nettype=static
	else
	    nettype=static
	fi
    }
}

ibft_nic=/sys/firmware/ibft/ethernet0
ibft_hostname=$(hostname)

if [ "$root_iscsi" = 1 -a -d $ibft_nic ]; then
    ibft_available=1
    ibft_set_iface
fi
save_var ibft_available
save_var ibft_hostname
save_var ibft_nic
