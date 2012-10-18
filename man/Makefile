A2X = a2x
A2X_OPTIONS = --doctype=manpage --format=manpage

all: cmdinitrd.8 lsinitrd.8 mkinitrd.5 mkinitrd.8

lsinitrd.8: lsinitrd.8.txt
	$(A2X) $(A2X_OPTIONS) $<

cmdinitrd.8: cmdinitrd.8.txt
	$(A2X) $(A2X_OPTIONS) $<

mkinitrd.5: mkinitrd.5.txt
	$(A2X) $(A2X_OPTIONS) $<

mkinitrd.8: mkinitrd.8.txt
	$(A2X) $(A2X_OPTIONS) $<

