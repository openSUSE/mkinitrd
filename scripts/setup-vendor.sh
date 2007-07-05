#!/bin/bash

if [ "$vendor_init_script" ] ; then
    cp_bin $vendor_init_script $vendor_script
fi

save_var vendor_init_script
