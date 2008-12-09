#!/bin/bash
#
#%stage: setup
#%depends: prepare
#%param_m: "Modules to include in initrd. Defaults to the INITRD_MODULES variable in /etc/sysconfig/kernel" "\"module list\"" modules
#%param_u: "Modules to include in initrd. Defaults to the DOMU_INITRD_MODULES variable in /etc/sysconfig/kernel." "\"DomU module list\"" domu_modules
#%param_d: "Root device. Defaults to the device from which / is mounted. Overrides the rootdev enviroment variable if set." root_device rootdev
#
shebang=/bin/bash

is_xen_kernel() {
    local kversion=$1
    local cfg

    for cfg in ${root_dir}/boot/config-$kversion $root_dir/lib/modules/$kversion/build/.config
    do
        test -r $cfg || continue
        grep -q "^CONFIG_XEN=y\$" $cfg
        return
    done
    test $kversion != "${kversion%-xen*}"
    return 
}

# Set in the mkinitrd script
save_var build_day

if [ -z "$param_m" ]; then
    # get INITRD_MODULES from system configuration
    . $root_dir/etc/sysconfig/kernel
    modules="$INITRD_MODULES"
fi

if [ -z "$param_u" ]; then
    # get DOMU_INITRD_MODULES from system configuration
    . $root_dir/etc/sysconfig/kernel
    domu_modules="$DOMU_INITRD_MODULES"
fi

# Activate features which are eqivalent to modules
for m in $modules ; do
    case "$m" in
        dm-multipath)
            ADDITIONAL_FEATURES="$ADDITIONAL_FEATURES multipath"
            ;;
    esac
done

save_var rootdev
root="$rootdev"
save_var root

if is_xen_kernel $kernel_version; then
    RESOLVED_INITRD_MODULES="$modules $domu_modules"
else
    RESOLVED_INITRD_MODULES="$modules"
fi

# Drivers with a firmware cannot be loaded via INITRD_MODULES mechanism
# because udev is needed to load the firmware. Put them in initrd, but don't
# load them via modprobe.
RESOLVED_INITRD_MODULES_NEW=
for m in $RESOLVED_INITRD_MODULES ; do
    if [ $(modinfo -F firmware $m 2> /dev/null | wc -l) -gt 0 ] ; then
        verbose "[SETUP]\tExcluding $m from INITRD_MODULES because of firmware"
    else
        RESOLVED_INITRD_MODULES_NEW="$RESOLVED_INITRD_MODULES_NEW $m"
    fi
done
RESOLVED_INITRD_MODULES=$RESOLVED_INITRD_MODULES_NEW

save_var RESOLVED_INITRD_MODULES
