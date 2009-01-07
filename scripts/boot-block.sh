#!/bin/bash
#%stage: device
#%provides: ideoptions scsioptions
#%udevmodules: $block_modules
#%if: "$block_modules"
#
##### Block device initialization
##
## this script translates module parameters given via command line to parameters
## used by the respective block device modules
##
## Command line parameters
## -----------------------
##
## ide                  additional options for the ide_core module
## hd?                  additional options for the ide_core module
## scsi_reportlun2=1    ??
## scsi_noreportlun=1   ??
## scsi_sparselun=1     ??
## scsi_largelun=1      ??
## llun_blklst          ??
## max_ghost_devices    ??
## max_sparseluns       ??
## max_luns             ??
## max_report_luns      ??
## inq_timeout          ??
## dev_flags            ??
## default_dev_flags    ??
##

[ "$(get_param ide)" ] && add_module_param ide_core "options=\"$(get_param ide)\""

function scsi_mod_check_compat() {
        p="$(get_param $1)"
        if [ "$p" ]; then
                echo "scsi_mod compat: Please use prefix: scsi_mod.$p"
                add_module_param scsi_mod $p
        fi
}

devflags=0
if [ "$(get_param scsi_reportlun2)" = "1" ]; then
        echo "scsi_reportlun2 compat: Use scsi_mod.default_dev_flags=0x20000 instead"
        devflags=$((131072+$devflags))
fi

if [ "$(get_param scsi_noreportlun)" = "1" ]; then
        echo "scsi_noreportlun compat: Use scsi_mod.default_dev_flags=0x40000 instead"
        devflags=$((262144+$devflags))
fi

if [ "$(get_param scsi_sparselun)" = "1" ]; then
        echo "scsi_sparselun compat: Use scsi_mod.default_dev_flags=0x40 instead"
        devflags=$((64+$devflags))
fi

if [ "$(get_param scsi_largelun)" = "1" ]; then
        echo "scsi_largelun compat: Use scsi_mod.default_dev_flags=0x200 instead"
        devflags=$((512+$devflags))
fi

if [ "$(get_param llun_blklst)" ]; then
        echo "llun_blklst is not supported any more"
        echo "use scsi_mod.dev_flags=VENDOR:MODEL:0x240[,V:M:0x240[,...]]"
fi

if [ "$(get_param max_ghost_devices)" ]; then
        echo "max_ghost_devices is not needed any more"
fi

if [ "$(get_param max_sparseluns)" ]; then
        echo "max_sparseluns not supported any more"
        echo "use scsi_mod.max_luns or enable the new REPORT_LUNS scsi"
        echo "scanning methods; try scsi_mod.default_dev_flags=0x20000"
fi

# check for (legacy) parameters
scsi_mod_check_compat max_luns
scsi_mod_check_compat max_report_luns
scsi_mod_check_compat inq_timeout
scsi_mod_check_compat dev_flags
scsi_mod_check_compat default_dev_flags

if [ $devflags != 0 ]; then
        add_module_param scsi_mod default_dev_flags=$devflags
fi

unset scsi_mod_check_compat
