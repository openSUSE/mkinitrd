#!/bin/bash
#
#%stage: device
#
if [ "$(echo $block_modules | grep sbp2)" ]; then
        root_firewire=1
fi

# no need to save the var, because the actual loader script does not do anything
