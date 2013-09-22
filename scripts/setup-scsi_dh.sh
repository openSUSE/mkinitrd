#!/bin/bash
#
#%stage: device
#
# Include all scsi_dh_* modules and load them on boot (bnc#727428 et al)

scsi_dh_modules=
if test -d $root_dir/lib/modules/$kernel_version/kernel/drivers/scsi/device_handler
then
	for i in $(find $root_dir/lib/modules/$kernel_version/kernel/drivers/scsi/device_handler -name "scsi[-_]dh[_-]*.ko")
	do
		i=${i%.ko}
		scsi_dh_modules="$scsi_dh_modules ${i##*/}"
	done
fi

save_var scsi_dh_modules
