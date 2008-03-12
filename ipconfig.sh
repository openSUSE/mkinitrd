#!/bin/bash
# 
# <client-ip>:<server-ip>:<gw-ip>:<netmask>:<hostname>:<device>:<autoconf>
#

# Calculate the prefix to a given netmask
calc_prefix() {
    local netmask=$1
    local prefix

    set -- $(IFS=.; echo $netmask)

    # Analyze each block
    prefix=0
    while [ "$1" ] && (( $1 == 255 )); do
	prefix=$(($prefix + 8))
	shift
    done
    # Bit-shift first non-zero block
    if [ "$1" ] && (( $1 > 0 )); then
	mask=$1
	prefix=$(($prefix + 8))
	while (( ($mask & 0x1) == 0 )) ; do
	    mask=$(( $mask >> 1 ))
	    prefix=$(($prefix - 1))
	done
    fi
    echo $prefix
}

# Calculate the network address
calc_network() {
    local ipaddr=$1
    local netmask=$2

    set -- $(IFS=.; echo $ipaddr)
    ipnum=$(( ($1 << 24) + ($2 << 16) + ($3 << 8) + $4 )) 
    set -- $(IFS=.; echo $netmask)
    netnum=$(( ($1 << 24) + ($2 << 16) + ($3 << 8) + $4 )) 

    netnum=$(( $ipnum & $netnum ))

    echo "$(( ($netnum >> 24) & 0xff )).$(( ($netnum >> 16) & 0xff )).$(( ($netnum >> 8) & 0xff )).$(( $netnum & 0xff ))"
}

if [ -z "$1" ] ; then
    exit 1
fi

ipcfg=$(echo $1 | sed 's/::/:_:/g')
ipcfg=$(echo $ipcfg | sed 's/::/:_:/g')

set -- $(IFS=: ; echo $ipcfg )

client=$1
shift
if [ "$1" != "_" ] ; then
    peer=$1
fi
shift
if [ "$1" != "_" ] ; then
    gateway=$1
fi
shift
if [ "$1" != "_" ] ; then
    netmask=$1
fi
shift
if [ "$1" != "_" ] ; then
    hostname=$1
fi
shift
if [ "$1" != "_" ] ; then
    dev=$1
else
    dev=eth0
fi
shift
if [ "$1" != "_" ] ; then
    mode=$1
fi
shift

# Calculate the prefix
prefix=${client%%*/}
if [ "$prefix" == "$client" ] ; then
    if [ -n "$netmask" ] ; then
	prefix=$(calc_prefix $netmask)
    else
	prefix=24
    fi
fi
network=$(calc_network $client $netmask)

# Configure the interface
if [ "$peer" ] ; then
    /sbin/ip addr add ${client} peer ${peer}/$prefix dev $dev
else
    /sbin/ip addr add ${client}/${prefix} dev $dev
fi
/sbin/ip link set $dev up
/sbin/ip route add to ${network}/${prefix} dev $dev

if [ "$gateway" ]; then
    /bin/ping -c 5 -w 5 -n $gateway
    /sbin/ip route add to default via ${gateway}
fi
