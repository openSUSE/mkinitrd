#!/bin/bash
#%stage: device
#%udevmodules: usbcore ohci_hcd uhci-hcd ehci_hcd xhci-hcd usbhid hid-logitech-dj hid-generic hid-holtek-kbd hid-lenovo-tpkbd hid-logitech-dj hid-ortek hid-roccat-arvo hid-roccat-isku hid-samsung hid-apple hid-belkin hid-cherry hid-ezkey hid-microsoft ehci-pci ohci-pci
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
