#
# Makefile for mkinitrd CVS
# $Id: Makefile,v 1.3.2.1 2004/10/18 11:59:55 olh Exp $
#

EXPORT_DIR = /tmp/cvs-checkouts/SLES9_BRANCH

CVS_ROOT = /suse/yast2/cvsroot

PKG = mkinitrd
BRANCH = SLES9_BRANCH

all: ex

ex: dirs
	cvs -d $(CVS_ROOT) export -d $(EXPORT_DIR)/$(PKG) -r $(BRANCH) $(PKG)
	rm -f $(EXPORT_DIR)/$(PKG)/Makefile

dirs: $(EXPORT_DIR)
	rm -rf $(EXPORT_DIR)/$(PKG)

$(EXPORT_DIR):
	mkdir -p $(EXPORT_DIR)
