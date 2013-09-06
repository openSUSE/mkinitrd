#!/bin/bash
#
#%stage: boot
#
# TODO: generate module deps and copy them to the initrd
#       take xen into account

# Global variables

# Array that stores additional dependencies. Each entry looks like
#       module:module1 module2
# The array is initialised with some known dependency and extended at runtime
# in the load_additional_dependencies function.
additional_module_dependencies=(
        "virtio:virtio_pci virtio_ring"
        "scsi_mod:sd_mod"
)

# Check if module $1 is listed in $modules.
has_module() {
    case " $modules " in
        *" $1 "*)   return 0 ;;
    esac
    return 1
}

# Check if any of the modules in $* are listed in $modules.
has_any_module() {
    local module
    for module in "$@"; do
        has_module "$module" && return 0
    done
}

# Add module $1 at the end of the module list.
add_module() {
    local module
    for module in "$@"; do
        has_module "$module" || modules="$modules $module"
    done
}

# Brief
#       Checks if the kernel version is supported at all.
#
# Description
#       Checks if the kernel version is supported. The background is: If we
#       have a kernel that is completely unsupported, we want to include all
#       modules even if the modules don't have the 'supported' attribute.
#       That allows us to use self-made kernels even on SUSE LINUX Enterprise.
#       The supported flag should not prevent users from running self-compiled
#       kernels on SLES but should prevent the loading of unsupported modules
#       on a supported kernel. Because the modprobe command is already aware
#       if it runs on a system that doesn't have the SUSE supported patch in
#       the kernel and then just loads the kernel module, we can safely include
#       such modules on such systems in initrd.
#
#       The check is done by checking if 'loop.ko' is supported. Since we have
#       supported loop for a very long period of time, and that module exists on
#       every architecture and does not depend on the hardware, that module is
#       suitable for that check. I didn't know any better method of checking if
#       the kernel is supported so I implemented that hack. Better than nothing.
#       :-)
#
# Parameters
#       kernelver: the kernel version
#
# Return value
#       0 (true) if the kernel is supported, 1 (false) if the kernel is not
#       supported
check_supported_kernel() {
    local kernel_version=$1
    local output=

    output=$(modinfo -k "$kernel_version" -F supported loop 2>/dev/null)
    if [ "$?" -ne 0 ] ; then
        # If the command existed with an error, assume that the kernel is
        # supported. That is just the same behaviour as before we did that
        # check_supported_kernel() hack
        verbose "[MODULES]\t'modinfo -k \"$kernel_version\" -F supported' " \
                "returned with an error."
        return 0
    fi

    if [[ "$output" = *yes* ]] ; then
        verbose "[MODULES]\tSupported kernel ($kernel_version)"
        return 0
    else
        verbose "[MODULES]\tUnsupported kernel ($kernel_version)"
        return 1
    fi
}

# Brief
#       Loads additional dependencies information
#
# Description
#       In /etc/modprobe.conf, /etc/modprobe.conf.local and /etc/modprobe.d/*
#       we have a special syntax
#
#               # SUSE INITRD: foo REQUIRES bar
#
#       to introduce additional dependencies which are expressed in the install
#       lines but cannot be parsed by mkinitrd statically.
#
#       This function loads that dependencies into the global
#       additional_module_dependencies array.
#
#       The function also scans for lines like
#
#              # SUSE INITRD: foot REQUIRES /bar
#
#       where /bar is the full path to the binary that is required. Of course
#       we know we have something like /sbin/modprobe there, but we can for
#       example include "sysctl" with that mechanism.
#
#       For that lines, we use cp_bin to actually include the binary.
load_additional_dependencies()
{
    for file in /etc/modprobe.conf \
                /etc/modprobe.conf.local \
                /etc/modprobe.d/* ; do
        # skip files if it does not exist
        if ! [ -r "$file" ] ; then
            continue
        fi

        grep '^# SUSE INITRD: ' $file >"$work_dir/pipe"
        while read line ; do
            local string module requirement dependencies dependency

            string=${line##*SUSE INITRD: }
            module=${string/ REQUIRES*}
            requirement=${string##*REQUIRES }

            if [ -z "$module" -o -z "$requirement" ] ; then
                echo >&2 "Requirement line '$line' in file '$file' is invalid."
                continue
            fi

            # file dependency
            if [[ "$requirement" == /* ]] ; then
                local dir=${requirement##*/}
                mkdir -p "$tmp_mnt/$dir"
                cp_bin "$requirement" "$tmp_mnt/$dir"
                verbose "[MODULES]\tIncluding $requirement per initrd comment"
            # module dependency
            else
                number=0
                added=0
                for entry in "${additional_module_dependencies[@]}" ; do
                    local module2 requirements2 val
                    module2=${entry/:*}
                    requirements2=${entry/*:}
                    if [ "$module2" = "$module" ] ; then
                        added=1
                        val="$module:$requirements2 $requirement"
                        additional_module_dependencies[$number]=$val
                        break
                    fi
                    number=$[number+1]
                done

                if [ $added -eq 0 ] ; then
                    additional_module_dependencies=( \
                            "${additional_module_dependencies[@]}" \
                            "$module:$requirement" )
                fi
            fi
        done < "$work_dir/pipe"
    done
}

# Brief
#       Returns additional module requirements from
#       additional_module_dependencies
#
# Description
#       Checks for a given kernel modules if there are additional dependencies
#       found by load_additional_dependencies.
#
#       Prints a list (separated by whitespace or newlines) of modules
#       if there are additional dependencies.
#
# Parameters
#       mod: the module for which additional depdencies should be found
get_add_module_deps()
{
    local mod=${1##*/}
    mod=${mod%.ko}

    for entry in "${additional_module_dependencies[@]}" ; do
        local module requirements

        module=${entry/:*}
        requirements=${entry/*:}
        if [ "$module" = "$mod" ] ; then
            echo $requirements
        fi
    done
}

# Resolve module dependencies and parameters. Returns a list of modules and
# their parameters.
resolve_modules() {
    local kernel_version=$1
    local module=
    local supported=
    local additional_args=
    local seen=
    shift

    if ! check_supported_kernel $kernel_version ; then
        additional_args=--allow-unsupported-modules
    fi

    while test $# -gt 0; do
        module=${1%.gz}
        module=${module%.ko}
        module=${module##*/}
        shift

        seen="$seen $module"
        # don't use a modprobe.conf to get rid of the install lines
        module_list=$(modprobe \
            -C /dev/null \
            --set-version $kernel_version --ignore-install \
            --show-depends $module \
            $additional_args 2> "$work_dir/pipe" \
            | grep -E '^(insmod|builtin) ')
        sed 's/^FATAL:/modprobe:/' "$work_dir/pipe" >&2
        if [ -z "$module_list" ]; then
            echo \
"WARNING: no dependencies for kernel module '$module' found." >&2
        fi
        module_list=$(echo "$module_list" | sed -rn 's/^insmod +([^ ]+).*/\1/p')
        for mod in $module_list ; do
            if ! $(echo $resolved_modules | grep -qF $mod) ; then
                resolved_modules="$resolved_modules $mod"

                # check for additional requirements specified by
                # SUSE INITRD comments in /etc/modprobe.conf{,local,.d/*}
                local additional_reqs req

                additional_reqs=$(get_add_module_deps "$mod" "$kernel_version")
                for req in $additional_reqs ; do
                    if ! printf '%s\n' "$@" $seen | grep -qFx "$req"; then
                        # put $req on the todo list to check for its
                        # dependencies
                        set -- "$@" "$req"
                    fi
                done
            fi
        done
    done
    echo $resolved_modules
}

resolve_modalias() {
    local tofind="$1" alias module

    while read a alias module; do
        case $tofind in $alias) echo "$module" ;;
        esac
    done < /lib/modules/$kernel_version/modules.alias
}

# gather all the modules we are supposed to copy
modules=
for script in $INITRD_PATH/boot/*.sh; do
    if use_script "$script"; then # only include the modules if the script gets used
        verbose -n ""
        for module in $(sed -rn 's/^#[[:blank:]]*%(udevmodules|modules):[[:blank:]]*(.*)$/\2/p' < $script); do
            [ "$module" ] && verbose "[MODULES]\t$(basename $script): $(eval echo $module)"
            add_module $(eval echo $module)
        done
    fi
done

# iscsi_ibft module is listed in the $INITRD_PATH/boot/*iscsi.sh script
# but is not valid on some archs. There should be a better way to handle
# this, but just remove it on such archs for now.
if [ ! -d /sys/firmware/ibft -a "${modules//iscsi_ibft/}" != "$modules" ] ; then
        modules=${modules//iscsi_ibft/}
	verbose "[MODULES]\tiscsi_ibft not present on this architecture, deleted from the list"
fi

# parsing of '# SUSE INITRD' lines
load_additional_dependencies

# cut out all modules which have a minus preceding them
modules=$(
for module in $modules; do
    skip=
    for m2 in $modules; do
        if [ "-$module" = "$m2" ]; then
            skip=1
        fi
    done
    [ ${module:0:1} = "-" ] && continue
    [ "$skip" ] || echo "$module"
done
)

resolved_modules="$(resolve_modules $kernel_version $modules)"
if [ $? -ne 0 ] ; then
    return 1
fi
if [ "$resolved_modules" ] ; then
    echo -ne "Kernel Modules:\t"
    for mod in $resolved_modules ; do
        modname=${mod##*/}
        modname="${modname%.gz}"
            echo -n "${modname%%.ko} "
    done
    echo
fi

# Copy all modules into the initrd
has_firmware=false
declare -A fw_array
mkdir -p $tmp_mnt/lib/firmware
mkdir -p $tmp_mnt/usr/lib
ln -sfbn ../../lib/firmware $tmp_mnt/usr/lib/firmware
for module in $resolved_modules; do
    if [ ! -r $root_dir/$module ]; then
        oops 9 "Module $module not found."
        continue
    fi
    if ! ( cd ${root_dir:-/} ; cp -p --parents $module $tmp_mnt ) ; then
        oops 6 "Failed to add module $module."
        rm -rf $tmp_mnt
        return 1
    fi
    # add any required firmware files
    for fw in $(modinfo -F firmware $module) ; do
        for dir in {/usr,}/lib/firmware{,/updates}; do
            for subdir in "" "$kernel_version"; do
                if test -e "$dir/$subdir/$fw"; then
                    cp -p --parents "$_" "$tmp_mnt"
                    if ! $has_firmware; then
                        echo -ne "Firmware:\t"
			has_firmware=true
                    fi
                    if test -z "${fw_array[$fw]}"
                    then
                        fw_array[$fw]=$fw
                        echo -n "$fw "
                    fi
                    if test -e "$dir/$subdir/$fw.sig"; then
                        cp -p --parents "$_" "$tmp_mnt"
                        echo -n "$fw.sig "
                    fi
                fi
            done
        done
    done
done
if $has_firmware; then
    echo
fi
unset has_firmware
unset fw_array

if [ "$resolved_modules" ] ; then
    [ ! -d $tmp_mnt/lib/modules/$kernel_version ] && oops 10 "No modules have been installed"
    for f in "/lib/modules/$kernel_version/"modules.{builtin,order}; do
        if test -e "$f"; then
            cp "$f" "$tmp_mnt/lib/modules/$kernel_version/"
        fi
    done
    depmod -b $tmp_mnt -e -F $map $kernel_version
fi


