#!/bin/bash
#
#%stage: boot
#%param_a: "Attach compiled ACPI DSDT (Differentiated System Description Table) to initrd. This replaces the DSDT of the BIOS. Defaults to the ACPI_DSDT variable in /etc/sysconfig/kernel." acpi_dsdt acpi_dsdt
#
# Attach ACPI DSDT if necessary.
attach_dsdt() {
    local initrd_image=$1
    local sdt_match

    if [ -z "$acpi_dsdt" ]; then
        acpi_dsdt="$ACPI_DSDT"
    fi
    if [ -z "$acpi_dsdt" ]; then
        return
    fi
    for sdt in $acpi_dsdt; do
        # File must be named: DSDT.aml or SSDT[0-9]*.aml
        # For compatibility reasons DSDT.aml can have an arbitrary
        # name if only DSDT should get overridden

        # sdt_type shows the type of the SDT (S or D)
        sdt_type=$(echo "$sdt" | sed 's/^.*\/\([SD]\)SDT[0-9]*\.aml$/\1/')
        # fallback for arbitrary file names
        if [ "${#sdt_type}" != 1 ]; then
            sdt_type=D
        fi
        if [ ! -f "$sdt" ]; then
            echo "[ACPI] ${sdt_type}SDT $sdt does not exist. Not including it."
            return
        elif ! grep -q "[SD]SDT" "$sdt" ; then
            echo "[ACPI] File $sdt is not a valid ACPI ${sdt_type}SDT. Not including it."
            return
        elif grep -qE 'DefinitionBlock' "$sdt" ; then
            echo "[ACPI] ${sdt_type}SDT $sdt does not seem to be in binary form. " \
                "Not including it."
            return
        elif [ ! "$(echo "$sdt" | sed -n '/\/[SD]SDT[0-9]*\.aml$/p')" ];then
            if [ "$renamed_dsdt" ];then
                echo "[ACPI] ($sdt) Multiple [DS]SDTs must be named: DSDT.aml or SSDT[0-9]*.aml"
                return
            else
                echo "[ACPI] Please rename $sdt to $(dirname $sdt)/DSDT.aml!"
                echo "[ACPI] Using compatibility mode (one DSDT only)."
                cp $sdt DSDT.aml
                renamed_dsdt=1
            fi
        else
            cp "$sdt" $tmp_mnt
        fi

        echo -e "ACPI ${sdt_type}SDT:\t$sdt"
    done
}

attach_dsdt

case "$(uname -m)" in
i?86 | x86_64 | ia64)
	acpi_modules="thermal processor fan"
esac
