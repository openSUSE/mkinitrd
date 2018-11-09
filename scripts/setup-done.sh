#!/bin/bash
#
#%stage: boot
#%depends: progs sharedlibs
#

COMPRESS="gzip -9"

if [[ $(uname -m) =~ ppc ]]
then
    COMPRESS="xz --check=crc32"
fi
pushd . > /dev/null 2>&1
cd $tmp_mnt
find bin sbin -type f -print0 | xargs -0 chmod 0755
# The initrd may contain sensitive information. Protect it from access
# by non-root users, and avoid a time window during initrd creation
# where it's unprotected.
if ! (umask 0077 && \
	  find . ! -name "*~" | cpio -H newc --create | $COMPRESS > $tmp_initrd)
then
    oops 8 "Failed to build initrd"
fi
popd > /dev/null 2>&1

# Make sure the permissions are safe while copying to final path.
tmp_initrd_1=$(mktemp "$initrd_image".XXXXXX)
initrd_ok=no
if [ -n "$tmp_initrd_1" ]; then
    if cp -f "$tmp_initrd" "$tmp_initrd_1"; then
	if mv -fT "$tmp_initrd_1" "$initrd_image"; then
	    initrd_ok=yes
	else
	    rm -f "$tmp_initrd_1"
	fi
    fi
fi
if [ o"$initrd_ok" != oyes ]; then
    oops 8 "Failed to install initrd"
fi
rm -rf $tmp_mnt

