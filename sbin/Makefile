#
# Dummy Makefile for mkinitrd sbin files
#

sbindir = /sbin

PRGS = mkinitrd installkernel module_upgrade mkinitrd_setup lsinitrd purge-kernels
all: install

install: $(PRGS)
	install -d $(DESTDIR)$(sbindir)
	install -m 755 $^ $(DESTDIR)$(sbindir)
