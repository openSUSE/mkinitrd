#
# Makefile for mkinitrd CVS
# $Id: Makefile,v 1.4 2006/04/18 17:34:34 olh Exp $
#

EXPORT_DIR = /tmp/cvs-checkouts

CVS_ROOT = /suse/yast2/cvsroot

PKG = mkinitrd
BRANCH = HEAD

all: ex

ex: dirs
	cvs -d $(CVS_ROOT) export -d $(EXPORT_DIR)/$(PKG) -r $(BRANCH) $(PKG)
	rm -f $(EXPORT_DIR)/$(PKG)/Makefile
	rm -f $(EXPORT_DIR)/$(PKG)/new-kernel-pkg

dirs: $(EXPORT_DIR)
	rm -rf $(EXPORT_DIR)/$(PKG)

$(EXPORT_DIR):
	mkdir -p $(EXPORT_DIR)
