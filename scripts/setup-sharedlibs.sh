#!/bin/bash
#
#%stage: boot
#%depends: progs busybox
#
# copy shared libraries to the initrd (dynamically resolved)

# helper
ldd_files() {
    local LDD file

    LDD=/usr/bin/ldd
    if [ ! -x $LDD ]; then
        error 2 "I need $LDD."
    fi

    for file; do
        if file -b "$file" | grep -q ' script '; then
            verbose "$file is a script"
            continue
        fi
        $LDD "$file"
    done | sed -ne 's:\t\(.* => \)\?\(/.*\) (0x[0-9a-f]*):\2:p' | sort -u
}

# Resolve dynamic library dependencies. Returns a list of symbolic links
# to shared objects and shared object files for the binaries in $*.
shared_object_files() {
    local initrd_libs lib link

    initrd_libs=( $(ldd_files "$@") )

    for lib in "${initrd_libs[@]}"; do
        case "$lib" in
            linux-gate*)
                # This library is mapped into the process by the kernel
                # for vsyscalls (i.e., syscalls that don't need a user/
                # kernel address space transition) in 2.6 kernels.
                continue ;;
            /lib/power*|/lib/ppc*)
                # Always include the base libraries for PowerPC
                lib="lib/${lib##*/}" ;;
            /lib64/power*|/lib64/ppc*)
                # Always include the base libraries for ppc64
                lib="lib64/${lib##*/}" ;;
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

copy_shared_libs() {
    local bins=( "$@" )
    local extra_lib_files lib_files lib i

    # First see what nss and other libs are required. This can be 64bit or 32bit,
    # depending on the host and the already copied binaries.
    case "$(uname -m)" in
        ia64)
            # this is a known location
            mkdir -p $tmp_mnt/lib
            extra_lib_files="`echo $root_dir/lib/libnss_{dns,files}* $root_dir/lib/lib{gcc_s,unwind}.so*`"
            ;;
        *)
            # Skip symlinks, they may point into the running system instead of $tmp_mnt
            for i in `LANG=C LC_ALL=C file -b $tmp_mnt/{,usr/}{lib*/udev,{,s}bin}/* | sed -n 's/^ELF \([0-9][0-9]-bit\) .*/\1/p' | sort -u`
            do
                case "$i" in
                    32-bit)
                        mkdir -p $tmp_mnt/lib
                        extra_lib_files="$extra_lib_files `echo $root_dir/lib/libnss_{dns,files}* $root_dir/lib/libgcc_s.so*`"
                        ;;
                    64-bit)
                        mkdir -p $tmp_mnt/lib64
                        extra_lib_files="$extra_lib_files `echo $root_dir/lib64/libnss_{dns,files}* $root_dir/lib64/libgcc_s.so*`"
                        ;;
                esac
            done
            ;;
    esac

    verbose -ne "Shared libs:\t"

    # Now collect a list of libraries on which the binaries and extra libs depend on
    lib_files=$( shared_object_files ${bins[@]} $extra_lib_files )
    if [ $? -eq 0 ]
    then
        if [ -n "$lib_files" ]
        then
            # Finally copy dependencies and extra libs
            for lib in $lib_files $extra_lib_files
            do
                [ -L $root_dir/$lib ] || verbose -n "$lib "
                ( cd ${root_dir:-/} ; cp -dp --parents $lib $tmp_mnt )
            done
            verbose
        else
            verbose "none"
        fi
    else
        return 1
    fi
}

# Copy all required shared libraries and the symlinks that refer to them.
copy_shared_libs "${initrd_bins[@]}"
