#!/bin/bash
#
#%stage: setup
#%depends: start

DRIVERS="i915"
supported_classes="0300"

# Find modules required for KMS. This is the gfx driver and an AGP module.
# To do this the PCI id list of every supported KMS capable DRM driver and
# the AGP driver are checked for their alias lists. These are compared with
# the installed hardware.

# Brief:
#        Set up arrays with PCI id information from driver.
# 
# Parameters:
#        List of alias strings as obtained by modinfo -F alias <module> as a single string.
#
# Return value:
#        None.
#
# Side effects:
#        The arrays device, vendor, subdevice, subvendor are set.
#        If one field doesn't contain an idea but a wildchard "*'
#        the corresponding entry in the array will be marked by 'X'.
#

declare -a device vendor subdevice subvendor class intf

parse_pciids_from_driver() {
    local pcilist="$1"
    local line
    local num=0
    OFS=$IFS
    local IFS="
"
    # get rid of the wicked "*"
    pcilist="${pcilist//\*/X}"
    for line in $pcilist
    do
	eval $line
	device[$num]=${d#0000}
	vendor[$num]=${v#0000}
	subdevice[$num]=${sd#0000}
	subvendor[$num]=${sv#0000}
	class[$num]=${bc}${sc}
	intf[$num]=${ii:0:2}
	num=$(( $num + 1 ))
    done
    IFS=$OFS
}

#
# Brief:
#          Obtain PCI ids of installed hardware.
#
# Parameters:
#          None.
#
# Return value:
#          None.
#
# Side effects:
#          The arrays m_slot, m_class, m_vendor, m_device, m_subvendor, m_subdevice
#          will be filled in.

declare -a m_slot m_class m_device m_vendor m_subdevice m_subvendor m_if

pciids_on_system()
{
    local line
    local n tmp
    local ct=0
    local ret=1
    declare -a entries
    OFS=$IFS
    local IFS="
"

    [ -d /sys/bus/pci ] && [ -n "$(type -p lspci)" ] || return 1

    for line in $(lspci -mn 2>/dev/null | tr "[:lower:]" "[:upper:]")
    do
	unset entries
	ret=0
	m_if[$ct]=00
	n=0
	IFS=$OFS
	for i in $line
	do
	    case $i in
		-P)
		    m_if[$ct]=${p#-p}
		    continue;
		    ;;
		-*) continue;
		    ;;
	    esac
	    entries[$n]=$i
	    n=$(( $n + 1 ))
	done
	m_slot[$ct]=${entries[0]//\"/}
	m_class[$ct]=${entries[1]//\"/}
	m_vendor[$ct]=${entries[2]//\"/}
	m_device[$ct]=${entries[3]//\"/}
	m_subvendor[$ct]=${entries[4]//\"/}
	m_subdevice[$ct]=${entries[5]//\"/}
	ct=$(( $ct + 1 ))
    done
    IFS=$OFS
    return $ret
}

#
# Brief:
#         Find out if driver supports one of the installed PCI ids.
#
# Parameters:
#         driver - driver module name without trailing .ko
#
# Return value:
#         Support level. When an ID matches exactly set the corresponding bit.
#         Vendor: 0, device: 1, subvendor: 2, subdevice: 3. The highest support
#         level is reported. If non of the entries map (because there is neither
#         an exact match not a wildchar map (or only wildchar matches but no exact
#         ones) return 0.

is_driver()
{
    local driver=$1
    local level=0
    local thislevel
    unset vendor device subvendor subdevice intf class
    local pcilist=$(modinfo -F alias -k $kernel_version $driver \
	| sed -n "s/pci:v\([0-9A-F\*]\+\)d\([0-9A-F\*]\+\)sv\([0-9A-F\*]\+\)sd\([0-9A-F\*]\+\)bc\([0-9A-F\*]\+\)sc\([0-9A-F\*]\+\)i\([0-9A-F\*]\+\).*/v=\1 d=\2 sv=\3 sd=\4 bc=\5 sc=\6 ii=\7/p")
    parse_pciids_from_driver "$pcilist"
    shopt -s nocasematch
    for i in ${!m_slot[@]}
    do
	for j in ${!device[@]}
	do
	    thislevel=0
	    if [ "${vendor[$j]}" = "X" -o "${m_vendor[$i]}" = "${vendor[$j]}" ]
	    then
		[ "${vendor[$j]}" != "X" ] && thislevel=$(( $thislevel + 1 ))
		if [ "${class[$j]}" = "X" ] || [[ "${m_class[$i]}" == "${class[$j]}" ]]
		then
		    [ "${class[$j]}" != "X" ] && thislevel=$(( $thislevel + 2 ))
		    if [ "${intf[$j]}" = "X" ] || [[ "${m_if[$i]}" == "${intf[$j]}" ]]
		    then
			[ "${intf[$j]}" != "X" ] && thislevel=$(( $thislevel + 4 ))
			if [ "${device[$j]}" = "X" ] || [[ "${m_device[$i]}" == "${device[$j]}" ]]
			then
			    [ "${device[$j]}" != "X" ] && thislevel=$(( $thislevel + 6 ))
			    if [ "${subvendor[$j]}" = "X" ] || [[ "${m_subvendor[$i]}" == "${subvendor[$j]}" ]]
			    then
				[ "${subvendor[$j]}" != "X" ] && thislevel=$(( $thislevel + 16 ))
				if [ "${subdevice[$j]}" = "X" ] || [[ "${m_subdevice[$i]}" == "${subdevice[$j]}" ]]
				then
				    [ "${subdevice[$j]}" = "X" ] && thislevel=$(( $thislevel + 32 ))
				    [ $thislevel -gt $level ] && level=$thislevel
				fi
			    fi
			fi
		    fi
		fi
	    fi
	done
    done
    echo $level
    shopt -u nocasematch
    return 0
}

#
# Brief:
#         Find all agp drivers installed for the specified kernel version
#
# Parameters:
#         kernel_version - specifies the kernel version string as printed by uname.
#
# Return value:
#         List of installed agp drivers.
#
# Side effects:
#         None.
#
agp_drivers()
{
    local kver=$1
    local agps

    for i in /lib/modules/$kver/kernel/drivers/char/agp/*.ko
    do
	i=${i##*/}
	i=${i%.ko}
	[ "$i" != "*" ] && agps="$agps $i"
    done
    echo "$agps"
}

#
# Brief:
#         Find driver for each installed PCI device which matches class.
#
# Parameters:
#         kernel_version, list of classes - kernel version is the version string asn
#         returned by uname for example. list of classes is a list of PCI classes 
#         (specified as 4-digit hex number) which are to be checked.
#
# Return value:
#         list of drivers.
#
# Side effects:
#         None.
#
class_drivers()
{
    local kver=$1
    local classlist="$2"
    local driver
    local gfxs
    local class
    local i j

    [ -z "$kver" ] && return 1

    shopt -s nocasematch
    for i in ${!m_class[@]}
    do
	for j in $classlist
	do
	    if [[ "${m_class[$i]}" == "$j" ]]
	    then
		class=${m_class[$i]}
		alias=pci:v0000${m_vendor[$i]}d0000${m_device[$i]}sv0000${m_subvendor[$i]}sd0000${m_subdevice[$i]}
		alias=${alias}bc${class:0:2}sc${class:2}i${m_if[$i]}
		driver=$(modprobe -n --resolve-alias --set-version $kver $alias)
		[ -n "$driver" ] && gfxs="$gfxs $driver"
		break
	    fi
	done
    done
    shopt -u nocasematch

    echo $gfxs
}


################## end of functions ######################

if [ "$NO_KMS_IN_INITRD" != "yes" ] && pciids_on_system
then

    gfx_modules=$(class_drivers $kernel_version $supported_classes)

    agpdrivers=$(agp_drivers $kernel_version)

    level=0
    for agpdriver in $agpdrivers
    do
	thislevel=$(is_driver $agpdriver)
	[ $thislevel -gt $level ] && { agp_module=${agpdriver##*/} ; level=$thislevel ; }
    done
    
    if [ "n$gfx_modules" != "n" ]
    then
	kms_modules="$agp_module $gfx_modules"
	echo -e "KMS drivers:    $kms_modules"
    fi
fi
save_var kms_modules
save_var gfx_modules
