#!/bin/bash

# Attach ACPI DSDT if necessary.
attach_dsdt() {
    local initrd_image=$1
    local sdt_match

    if [ -z "$acpi_dsdt" ]; then
	if [ -f /etc/sysconfig/kernel ]; then
	    . /etc/sysconfig/kernel
	    acpi_dsdt="$ACPI_DSDT"
	fi
    fi
    if [ -z "$acpi_dsdt" ]; then
	return
    fi
    for sdt in "$acpi_dsdt";do
	# File must be named: DSDT.aml or SSDT[0-9]*.aml
	sdt_match=`expr match $(echo $sdt) ".*[SD]SDT[0-9]*\.aml"`
	if [ $sdt_match -lt 8 ];then
	    oops 2 "($sdt) [DS]SDT must be named: DSDT.aml or SSDT[0-9]*.aml"
	    return
	fi
	if [ ! -f "$sdt" ]; then
	    oops 2 "ACPI DSDT $sdt does not exist."
	    return
	fi
	if ! grep -q "[SD]SDT" "$sdt" ; then
	    oops 2 "File $sdt is not a valid ACPI DSDT. Ignoring."
	    return
	elif grep -qE 'DefinitionBlock' "$sdt" ; then
	    oops 2 "ACPI DSDT $sdt does not seem to be in binary form." \
		"Will not attach this to $initrd_image."
	    return
	fi

	cp "$sdt" $tmp_mnt

	echo -e "ACPI DSDT:\t$sdt"
    done
}

    attach_dsdt

    pushd . > /dev/null 2>&1
    cd $tmp_mnt
    find bin sbin -type f -print0 | xargs -0 chmod 0755 
    find . ! -name "*~" | cpio -H newc --create | gzip -9 > $tmp_initrd.gz
    popd > /dev/null 2>&1
    if ! cp -f $tmp_initrd.gz $initrd_image ; then
	oops 8 "Failed to install initrd"
    fi
    rm -rf $tmp_mnt

