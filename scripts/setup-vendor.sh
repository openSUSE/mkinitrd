#!/bin/bash
#
#%stage: boot
#%param_V: "Vendor specific script to run in linuxrc (deprecated)." script vendor_init_script
#
if [ "$vendor_init_script" ] ; then
    cp_bin $vendor_init_script $vendor_script
fi

save_var vendor_init_script
