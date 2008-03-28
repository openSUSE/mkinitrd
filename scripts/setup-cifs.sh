#!/bin/bash
#
#%stage: device
#

if [ "$rootfstype" = "cifs" ]; then
    interface=default
    save_var rootfstype
fi
