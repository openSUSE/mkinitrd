#!/bin/bash
#
#%stage: setup
#
# Include paravirtualized drivers for fully virtualized guests even if
# the guest is currently booted with emulated hardware.
#

check_hyperv_guest() {
  local board_vendor
  local product_name
  local dmi=/sys/class/dmi/id
  if test -r "${dmi}/board_vendor" -a -r "${dmi}/product_name"
  then
    read board_vendor < "${dmi}/board_vendor"
    read product_name < "${dmi}/product_name"
    if test "${product_name}" = "Virtual Machine" -a "${board_vendor}" = "Microsoft Corporation"
    then
      return 0
    fi
  fi
  return 1
}

check_xen_PVonHVM() {
  local product_name
  local sys_vendor
  local dmi=/sys/class/dmi/id
  if test -r "${dmi}/product_name" -a -r "${dmi}/sys_vendor"
  then
    read product_name < "${dmi}/product_name"
    read sys_vendor < "${dmi}/sys_vendor"
    if test "${sys_vendor}" = "Xen" -a "${product_name}" = "HVM domU"
    then
      return 0
    fi
  fi
  return 1
}

if check_hyperv_guest ; then
  fv_guest_modules="hv_storvsc hv_netvsc hyperv_fb hyperv-keyboard"
elif check_xen_PVonHVM ; then
  # Use aliases because the module names differ in xenlinux and pv_ops kernel:
  # xen:vbd xen-vbd  xen-blkfront
  # xen:vif xen-vnif xen-netfront
  fv_guest_modules="xen:vbd xen:vif"
fi

