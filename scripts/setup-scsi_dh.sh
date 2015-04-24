
#!/bin/bash
#
#%stage: device
#
# Include active scsi_dh_* modules and load them on boot
# (bnc#727428 et al, bsc#926440)
#

scsi_dh_modules=
for bd in $blockdev ; do
    update_blockdev $bd
    devpath=/sys/dev/block/${blockmajor}:${blockminor}/device
    [ -L ${devpath} ] || continue
    [ -f ${devpath}/dh_state ] || continue
    dh_name=$(cat ${devpath}/dh_state)
    [ "$dh_name" = "detached" ] && continue

    for i in $(find $root_dir/lib/modules/$kernel_version/kernel/drivers/scsi/device_handler -name "scsi[-_]dh[_-]${dh_name}.ko"); do
	i=${i%.ko}
	scsi_dh_modules="$scsi_dh_modules ${i##*/}"
    done
done

save_var scsi_dh_modules
