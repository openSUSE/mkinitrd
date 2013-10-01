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

parse_prefix() {
    local arg="$1"

    case "$arg" in
        *.*)
            # a.b.c.d IPv4 address
            calc_prefix "$arg"
            ;;
        /*)
            # /n
            arg="${arg:1}"
            echo $[arg]
            ;;
        *)
            # prefix length
            echo $[arg]
            ;;
    esac
}

if [ "${1:0:1}" = "[" ]; then
    cfg="${1:1}"
    client="${cfg%%]:*}"
    cfg="${cfg#*]:}"
else
    client="${1%%:*}"
    cfg="${1#*:}"
fi

ipcfg=$(echo "$cfg" | sed 's/:/_:/g')

set -- $(IFS=: ; echo $ipcfg )

if [ "$1" != "_" ] ; then
    peer=${1%%_}
fi
shift
if [ "$1" != "_" ] ; then
    gateway=${1%%_}
fi
shift
if [ "$1" != "_" ] ; then
    netmask=${1%%_}
fi
shift
if [ "$1" != "_" ] ; then
    hostname=${1%%_}
fi
shift
if [ "$1" != "_" ] ; then
    dev=${1%%_}
else
    dev=eth0
fi
shift
if [ "$1" != "_" ] ; then
    mode=${1%%_}
fi
shift

# Calculate the prefix
prefix=${client%%*/}
if [ "$prefix" == "$client" ] ; then
    if [ -n "$netmask" ] ; then
        prefix=$(parse_prefix $netmask)
    else
        case "$client" in
            *:*) prefix=64 ;;
            *)   prefix=24 ;;
        esac
    fi
fi

# Configure the interface
if [ "$peer" ] ; then
    ip addr add ${client} peer ${peer}/$prefix dev $dev
else
    ip addr add ${client}/${prefix} dev $dev
fi
ip link set $dev up

if [ "$gateway" ]; then
    ip route add to default via ${gateway}
fi
