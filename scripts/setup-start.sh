#!/bin/bash
#
#%stage: setup
#%depends: prepare
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

if [ -z "$modules_set" ]; then
    # get INITRD_MODULES from system configuration
    . $root_dir/etc/sysconfig/kernel
    modules="$INITRD_MODULES"
fi

if [ -z "$domu_modules_set" ]; then
    # get DOMU_INITRD_MODULES from system configuration
    . $root_dir/etc/sysconfig/kernel
    domu_modules="$DOMU_INITRD_MODULES"
fi

save_var rootdev
root="$rootdev"
save_var root

if is_xen_kernel $kernel_version; then
    RESOLVED_INITRD_MODULES="$domu_modules"
else
    RESOLVED_INITRD_MODULES="$modules"
fi
save_var RESOLVED_INITRD_MODULES
