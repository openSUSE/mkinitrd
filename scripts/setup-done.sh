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
# If the target file exists already, cp doesn't change permissions.
# Even cp -p applies permissions only after copying the contents, leaving
# a small race window open.
# We could simply "rm -f" the image, but then in case of failure the user
# would be left without initrd. Try chmod.
if [ -e $initrd_image ]; then
    chmod 0600 $initrd_image || oops 8 "Failed to set initrd permissions"
fi
if ! (umask 0077 && cp -f $tmp_initrd $initrd_image) ; then
    oops 8 "Failed to install initrd"
fi
rm -rf $tmp_mnt

