#!/bin/bash
# copy programs to the initrd

for script in $INITRD_PATH/boot/*.sh; do
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
		cp_bin "$SOURCE" "$DEST"
	    done
	done
    fi
done

echo -ne "Features:       "
echo $features

[ -e "bin/sh" ] || ln -s /bin/bash bin/sh

