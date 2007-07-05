#!/bin/bash
# TODO: generate module deps and copy them to the initrd
# 	take xen into account

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

# Resolve module dependencies and parameters. Returns a list of modules and
# their parameters.
resolve_modules() {
    local kernel_version=$1 module
    shift

    for module in "$@"; do
	local with_modprobe_conf
	module=${module%.o}  # strip trailing ".o" just in case.
	module=${module%.ko}  # strip trailing ".ko" just in case.
	if [ -e /etc/modprobe.conf ]; then
	    with_modprobe_conf="-C /etc/modprobe.conf"
	fi
	module_list=$(/sbin/modprobe $with_modprobe_conf \
	    --set-version $kernel_version --ignore-install \
	    --show-depends $module 2> /dev/null \
	    | sed -ne 's:.*insmod /\?::p' | sed -ne 's:\ .*\?::p' )
	if [ ! "$module_list" ]; then
	    echo \
"WARNING Cannot determine dependencies of kernel module '$module'.
	Does it exist? If it does, try depmod -a. Continuing without $module." >&2
	fi
	for mod in $module_list ; do
	    if ! $(echo $resolved_modules | grep -q $mod) ; then
		resolved_modules="$resolved_modules $mod"
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
	for module in $(cat $script | egrep '%udevmodules: |%modules: ' | sed 's/^.*s: \(.*\)$/\1/'); do
	    [ "$module" ] && verbose "[MODULES]\t$(basename $script): $(eval echo $module)"
	    add_module $(eval echo $module)
	done
    fi
done

resolved_modules="$(resolve_modules $kernel_version $modules)"
if [ $? -ne 0 ] ; then
    return 1
fi

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

echo -ne "Kernel Modules:\t"
for mod in $resolved_modules ; do
    modname=${mod##*/}
    echo -n "${modname%%.ko} "
done
echo

# Copy all modules into the initrd
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
done

if [ "$resolved_modules" ] ; then
    [ ! -d $tmp_mnt/lib/modules/$kernel_version ] && oops 10 "No modules have been installed"
    ( cd $tmp_mnt; /sbin/depmod -b $tmp_mnt -e -F $map $kernel_version )
fi


