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
	    | sed -ne 's:.*insmod /\?::p' )
	if [ "$module" != "af_packet" ] && [ -z "$module_list" ]; then
	    oops 7 "Cannot determine dependencies of module $module." \
		"Is modules.dep up to date?"
	fi
	echo "$module_list"
    done \
    | awk ' # filter duplicates: we must not reorder modules here!
	NF == 0     { next }
	$1 in seen  { next }
		    { seen[$1]=1
		      # drop module parameters here: modprobe in the initrd
		      # will pick them up again.
		      print $1
		    }
    '
    rm -f $temp
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
for script in $INITRD_PATH/boot/*; do
    if use_script "$script"; then # only include the modules if the script gets used
	verbose -n ""
	for module in $(cat $script | egrep '%udevmodules: |%modules: ' | sed 's/^.*s: \(.*\)$/\1/'); do
	    [ "$module" ] && verbose "[MODULES]\t$(basename $script): $(eval echo $module)"
	    modules="$modules $(eval echo $module)"
	done
    fi
done

echo -ne "Kernel Modules:\t"
(
shownmodules=
for module in $modules; do
    readmodule=${module##*/}
    readmodule=${readmodule%*.ko}
    show=1
    for smodule in $shownmodules; do
    	if [ "$smodule" = "$module" ]; then
    	    show=
    	fi
    done
    if [ "$show" ]; then
	shownmodules="$shownmodules $readmodule"
	
    	if [ $readmodule != "${readmodule%:*}" ]; then
    	    resolved_modalias="$(resolve_modalias $readmodule)"
	    shownmodules="$shownmodules $resolved_modalias"
	    echo -n "$readmodule("
	    COMMA=
	    for modalias in $resolved_modalias; do
		echo -n ${COMMA}${modalias}
		[ ! "$COMMA" ] && COMMA=,
    	    done
	    echo ")"
    	else
	    echo "$readmodule "
        fi
    fi
done
) | sort | uniq | (while read a; do echo -n "$a "; done) # print a sorted module list (easier to find modules)
echo

resolved_modules="$(resolve_modules $kernel_version $modules)"

#echo "modules: $modules"
#echo "resolved modules: $resolved_modules"

    # Copy all modules into the initrd
    for module in $resolved_modules; do
#	echo "copy module $module"
        if [ ! -r $root_dir/$module ]; then
            oops 9 "Module $module not found."
            continue
        fi
        if ! ( cd ${root_dir:-/} ; cp -p --parents $module $tmp_mnt ) ; then
            oops 6 "Failed to add module $module."
            rm -rf $tmp_mnt
            return
        fi
    done

    # And run depmod to ensure proper loading
    if [ "$sysmap" ] ; then
        map="$sysmap"
    else
        map=$root_dir/boot/System.map-$kernel_version
    fi
    if [ ! -f $map ]; then
        map=$root_dir/boot/System.map
    fi
    if [ ! -f $map ]; then
        oops 9 "Could not find map $map, please specify a correct file with -M."
        rm -rf $tmp_mnt
        return
    fi

    [ -d $tmp_mnt/lib/modules/$kernel_version ] || mkdir -p $tmp_mnt/lib/modules/$kernel_version
    ( cd $tmp_mnt; /sbin/depmod -b $tmp_mnt -e -F $map $kernel_version )


