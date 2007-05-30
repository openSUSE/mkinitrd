#!/bin/bash
#%requires: firewire
#%udevmodules: usbcore hci_usb ohci_hcd uhci-hcd ehci_hcd usbhid hid
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
