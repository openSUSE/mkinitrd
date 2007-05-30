#!/bin/bash
# copy programs and libraries to the initrd

# Resolve dynamic library dependencies. Returns a list of symbolic links
# to shared objects and shared object files for the binaries in $*.
shared_object_files() {
    local LDD CHROOT initrd_libs lib_files lib_links lib link

    LDD=/usr/bin/ldd
    if [ ! -x $LDD ]; then
	error 2 "I need $LDD."
    fi

    initrd_libs=( $(
	for i in "$@" ; do $LDD "$i" ; done \
	| sed -ne 's:\t\(.* => \)\?\(/.*\) (0x[0-9a-f]*):\2:p'
    ) )

    # Evil hack: On some systems we have generic as well as optimized
    # libraries, but the optimized libraries may not work with all
    # kernel versions (e.g., the NPTL glibc libraries don't work with
    # a 2.4 kernel). Use the generic versions of the libraries in the
    # initrd (and guess the name).
    local n optimized
    for ((n=0; $n<${#initrd_libs[@]}; n++)); do
	lib=${initrd_libs[$n]}
	optimized="$(echo "$lib" | sed -e 's:.*/\([^/]\+/\)[^/]\+$:\1:')"
	lib=${lib/$optimized/}
	if [ "${optimized:0:3}" != "lib" -a -f "$lib" ]; then
	    #echo "[Using $lib instead of ${initrd_libs[$n]}]" >&2
	    initrd_libs[$n]="${lib/$optimized/}"
	fi
    done

    for lib in "${initrd_libs[@]}"; do
	case "$lib" in
	linux-gate*)
	    # This library is mapped into the process by the kernel
	    # for vsyscalls (i.e., syscalls that don't need a user/
	    # kernel address space transition) in 2.6 kernels.
	    continue ;;
	/*)
	    lib="${lib:1}" ;;
	*)
	    # Library could not be found.
	    oops 7 "Dynamic library $lib not found"
	    continue ;;
	esac

	while [ -L "/$lib" ]; do
	    echo $lib
	    link="$(readlink "/$lib")"
	    if [ x"${link:0:1}" == x"/" ]; then
	        lib=${link#/}
	    else
	        lib="${lib%/*}/$link"
	    fi
	done
	echo $lib
    done \
    | sort -u
}

# binary files
declare -i script_counter
script_counter=100

for script in $INITRD_PATH/boot/*; do
    if use_script "$script"; then # only include the programs if the script gets used
    	# add the script to the feature list if no #%dontshow line was given
	feature="${script##*/}"
	feature="${feature#*-}"
	feature="${feature%.sh}"
    	if [ ! "$(cat $script | grep '%dontshow')" ]; then
	    features="$features $feature"
    	fi
	# copy the script itself
	cp_bin "$script" boot/
	# and all programs it needs
	for files in $(cat $script | grep '%programs: ' | sed 's/^#%programs: \(.*\)$/\1/'); do
	    for file in $(eval echo $files); do
		if [ "${file:0:17}" = "/lib/mkinitrd/bin" ]; then
			SOURCE=$file
			DEST="./bin/"
		elif [ "${file:0:1}" = "/" ]; then # absolute path files have to stay alive
			SOURCE=$file
			[ ! -e $file -a -e /usr$file ] && SOURCE="/usr$file"
			DEST=".$file"
		else
			SOURCE=$(which "$file")
			DEST="./bin/"
		fi
#		echo "copying $SOURCE => $DEST ..."
		cp_bin "$SOURCE" "$DEST"
	    done
	done
    fi
done

echo -ne "Features:       "
echo $features

[ -e "bin/sh" ] || ln -s /bin/bash bin/sh

#    echo -ne "Shared libs:\t"
    # Copy all required shared libraries and the symlinks that
    # refer to them.
    lib_files=$(shared_object_files "${initrd_bins[@]}")
    [ $? -eq 0 ] || return 1
    if [ -n "$lib_files" ]; then
	for lib in $lib_files; do
#	    [ -L $root_dir/$lib ] || echo -n "$lib "
	    ( cd ${root_dir:-/} ; cp -dp --parents $lib $tmp_mnt )
	done
	lib_files=
	case "$(uname -m)" in
		alpha|ia64)
			mkdir -p $tmp_mnt/lib
			lib_files="$lib_files `echo $root_dir/lib/libnss_files* $root_dir/lib/libgcc_s.so*`"
			;;
		*)
			# no symlinks, most point into the running system
			for i in `LANG=C LC_ALL=C file -b $tmp_mnt/{,usr/}{lib*/udev/,{,s}bin}/* | awk '/^ELF ..-bit/ { print $2 }' | sort -u`
			do
				case "$i" in
					32-bit)
						mkdir -p $tmp_mnt/lib
						lib_files="$lib_files `echo $root_dir/lib/libnss_files* $root_dir/lib/libgcc_s.so*`"
						;;
					64-bit)
						mkdir -p $tmp_mnt/lib64
						lib_files="$lib_files `echo $root_dir/lib64/libnss_files* $root_dir/lib64/libgcc_s.so*`"
						;;
				esac
			done
		;;
	esac

	for lib in $lib_files ; do
	    if [ -f $lib ] ; then
#		echo -n "${lib##$root_dir/} "
		cp -dp --parents $lib $tmp_mnt
	    fi
	done
#	echo
#    else
#	echo "none"
    fi

