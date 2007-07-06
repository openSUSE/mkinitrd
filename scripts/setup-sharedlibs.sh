#!/bin/bash
#
#%stage: boot
#%depends: progs
#
# copy shared libraries to the initrd (dynamically resolved)

# Resolve dynamic library dependencies. Returns a list of symbolic links
# to shared objects and shared object files for the binaries in $*.
shared_object_files() {
    local LDD CHROOT initrd_libs lib_files lib_links lib link

    LDD=/usr/bin/ldd
    if [ ! -x $LDD ]; then
	error 2 "I need $LDD."
    fi

    initrd_libs=( $(
	$LDD "$@" \
	| sed -ne 's:\t\(.* => \)\?\(/.*\) (0x[0-9a-f]*):\2:p' \
	| sort | uniq
    ) )

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
    done
}

verbose -ne "Shared libs:\t"
# Copy all required shared libraries and the symlinks that
# refer to them.
lib_files=$(shared_object_files "${initrd_bins[@]}")
[ $? -eq 0 ] || return 1
if [ -n "$lib_files" ]; then
    for lib in $lib_files; do
	[ -L $root_dir/$lib ] || verbose -n "$lib "
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
	    verbose -n "${lib##$root_dir/} "
	    cp -dp --parents $lib $tmp_mnt
	fi
    done
    verbose
else
    verbose "none"
fi

