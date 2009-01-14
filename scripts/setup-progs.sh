#!/bin/bash
#
#%stage: boot
#
# copy programs to the initrd

for script in $INITRD_PATH/boot/*.sh; do
    if use_script "$script"; then # only include the programs if the script gets used
        # add the script to the feature list if no #%dontshow line was given
        file="${script##*/}"
        feature="${file#*-}"
        feature="${feature%.sh}"
        if [ ! "$(cat $script | grep '%dontshow')" ]; then
            features="$features $feature"
        fi
        # copy the script itself
        cp -pL "$script" boot/
        # add an entry to the boot wrapping script
        echo "[ \"\$debug\" ] && echo preping $file" >> run_all.sh
        # -- load config for the current module
        [ -e "config/${file#*-}" ] && cat "config/${file#*-}" >> run_all.sh
        # echo "[ -e "config/${file#*-}" ] && . \"config/${file#*-}\"" >> run_all.sh
        # -- check if we should run the module
        condition="$(sed -n 's/^#%if:\(.*\)$/if [ \1 ]; then/p' "$script")"
          echo "$condition" >> run_all.sh
          # -- remember dependent modules
          sed -n 's/^#%modules:\(.*\)$/modules="\1"/p' $script >> run_all.sh
          echo "[ \"\$debug\" ] && echo running $file
source boot/$file
[ \"\$modules\" ] && load_modules" >> run_all.sh
        [ "$condition" ] && echo "fi" >> run_all.sh
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

                # if we're given a symlink, always copy the linked file too
                if [ -L "$SOURCE" ]; then
                    LINK=$(readlink -e "$SOURCE")
                    if [ -e "$LINK" ]; then
                        mkdir -p .$(dirname "$LINK")
                        cp_bin "$LINK" ."$LINK"
                    else
                        echo 2>&1 "WARNING: $LINK is a dangling symlink"
                    fi
                else
                    cp_bin "$SOURCE" "$DEST"
                fi
            done
        done
    fi
done

echo -ne "Features:       "
echo $features

[ -e "bin/sh" ] || ln -s /bin/bash bin/sh

