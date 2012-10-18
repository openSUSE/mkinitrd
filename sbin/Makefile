#
# Dummy Makefile for mkinitrd sbin files
#

sbindir = /sbin
bindir = /bin

PRGS = mkinitrd installkernel module_upgrade mkinitrd_setup purge-kernels
UPRGS = lsinitrd cmdinitrd
all: install
install: install_prgs install_uprgs

install_prgs: $(PRGS)
	install -d $(DESTDIR)$(sbindir)
	install -m 755 $^ $(DESTDIR)$(sbindir)

install_uprgs: $(UPRGS)
	install -d $(DESTDIR)$(bindir)
	install -m 755 $^ $(DESTDIR)$(bindir)
