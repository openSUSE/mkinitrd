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
        if ! grep -q '%dontshow' < "$script" ; then
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
        condition="$(sed -rn 's/^#[[:blank:]]*%if:[[:blank:]]*(.*)$/if [ \1 ]; then/p' < "$script")"
          echo "$condition" >> run_all.sh
          # -- remember dependent modules
          sed -rn 's/^#[[:blank:]]*%modules:[[:blank:]]*(.*)$/modules="\1"/p' < $script >> run_all.sh
          echo "[ \"\$debug\" ] && echo running $file
source boot/$file
[ \"\$modules\" ] && load_modules" >> run_all.sh
        [ "$condition" ] && echo "fi" >> run_all.sh
        # and all programs it needs
        for files in $(sed -rn 's/^#[[:blank:]]*%programs:[[:blank:]]*(.*)$/\1/p' < "$script"); do
            for file in $(eval echo $files); do
                if [ "${file:0:17}" = "/lib/mkinitrd/bin" ]; then
                        SOURCE=$file
                        DEST="./bin/"
                elif [ "${file:0:1}" = "/" ]; then # absolute path files have to stay alive
                        SOURCE=$file
                        [ ! -e $file -a -e /usr$file ] && SOURCE="/usr$file"
                        DEST=".$SOURCE"
                else
                        case "$(type -t "$file")" in
                        builtin) continue
                        esac
                        SOURCE=$(type -p "$file")
                        DEST=".$SOURCE"
                fi

                cp_bin "$SOURCE" "$DEST"
            done
        done
    fi
done

echo -ne "Features:       "
echo $features

[ -e "bin/sh" ] || ln -s /bin/bash bin/sh

