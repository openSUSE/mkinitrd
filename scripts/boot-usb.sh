#!/bin/bash
#%stage: device
#%udevmodules: usbcore ohci_hcd uhci-hcd ehci_hcd xhci-hcd usbhid
#%if: "$use_usb"
#
##### usb module helper
##
## This script provides us with all core usb modules.
## Additionally this script provides us with the usb 
## HID modules so we are able to use a usb keyboard.
##
## Command line parameters
## -----------------------
##

if test -n "$cmd_1" -o -n "$cmd_s" -o -n "$cmd_single"; then
	modules="usbcore ohci-hcd uhci-hcd ehci-hcd xhci-hcd usbhid"
	load_modules
fi
