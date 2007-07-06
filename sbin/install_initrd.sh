#!/bin/bash
#
# Install initrd scripts
#

update_dependency()
{
    local newlevel

    section=${1#$2/}
    section=${section%%/*}
    file=$1
    read level < $1/level
    name=${1##*/}
    file=${1%/depends/$name}
    name=${file##*/}
    if [ ! -f $file/level ] ; then
	echo "Unresolved dependency for $name"
	return
    fi
    read oldlevel < $file/level
    if [ $oldlevel -le $level ] ; then
	newlevel=$((level + 1))
    fi
    if [ "$newlevel" ] && [ $oldlevel -ne $newlevel ] ; then
	echo $newlevel > $file/level
    fi

    case "$file" in
	*/depends/*)
	    update_dependency $file $2 ;;
    esac
}

offset=1
installdir=lib/mkinitrd

if [ ! -d "$installdir" ] ; then
    echo "Installation error: directory $installdir not found"
    exit 1
fi

if [ ! -f "$installdir/stages" ] ; then
    echo "Installation error: file $installdir/stages not found"
    exit 1
fi

tmpdir=$installdir/.tmpdir
rm -rf $tmpdir

# Generate levels
echo "Generate levels ..."
level=0
level_list=
while read stage ; do
    case $stage in
	\#*)
        stage= ;;
    esac
    [ -z "$stage" ] && continue
    if [ -n "$(eval echo \$level_$stage)" ] ; then
	echo "Duplicate stage $stage, ignoring entry"
	continue
    fi
    eval level_$stage=$level
    #  echo "Level ${stage}: $(eval echo \$level_$stage)"
    level_list="$level_list $level"
    stage_list="$stage_list $stage"
    level=$((level + 1))
    if [ ! -d $tmpdir/boot/$stage ] ; then
	mkdir -p $tmpdir/boot/$stage
    fi
    if [ ! -d $tmpdir/setup/$stage ] ; then
	mkdir -p $tmpdir/setup/$stage
    fi
done < $installdir/stages

if [ $level -gt 10 ] ; then
    echo "Too many stages (found ${level}, max 10). Exit."
    exit 1
fi

# Scan setup files
echo "Scan scripts ..."
for script in scripts/*.sh ; do
    stage=$(sed -n 's/#%stage: \(.*\)/\1/p' $script)
    depends=$(sed -n 's/#%depends: \(.*\)/\1/p' $script)
    provides=$(sed -n 's/#%provides: \(.*\)/\1/p' $script)
    file=${script##*/}
    name=${script##*-}
    name=${name%.sh}
    section=${file%-*.sh}

    if [ -z "$stage" ] ; then
	echo "Missing #%stage keyword in script $script"
	continue;
    fi

    dirname=$tmpdir/$section/$stage

    if [ ! -d $dirname ] ; then
	echo "Invalid stage $stage in script $script"
	continue;
    fi
    if [ -d $dirname/$name ] ; then
	echo "Duplicate script name $name"
	continue;
    fi
    mkdir $dirname/$name
    level=$(eval echo \$level_$stage)
    if [ "$section" = "setup" ] ; then
	printf "%d\n" $((level * 10 + 1)) > $dirname/$name/level
    else
	printf "%d\n" $((91 - level * 10)) > $dirname/$name/level
    fi
    mkdir $dirname/$name/provides
    for dir in $name $provides ; do
	touch $dirname/$name/provides/$dir
    done
    if [ -n "$depends" ] ; then
	mkdir $dirname/$name/depends
	for d in $depends; do
	    (cd $dirname/$name/depends; ln -s ../../$d $d)
	done
    fi
done

# Resolve dangling symlinks
echo "Resolve %provides ..."
for file in $(find $tmpdir -regex .*depends\\/.* -print) ; do
    depdir=${file%/*}
    dir=${depdir%/*}
    depends=${file##*/}
    name=${dir##*/}
    section=${file#$tmpdir/}
    section=${section%%/*}
    if [ ! -f $file/level ] ; then
	for f in $(find $tmpdir/$section -regex .*provides.$depends -print); do
	    t=${f%/provides/$depends}
	    n=${t##*/}
	    (cd $depdir; ln -s ../../$n $n)
	    # echo "Resolving $section/$depends to $n"
	done
	rm $file
    fi
done

# Resolve dependencies
echo "Resolve %depends ..."
for file in $(find -L $tmpdir -regex .*depends\\/.* -print | sed '/provides/d;/level/d;/depends$/d' ) ; do
    update_dependency $file $tmpdir
done

# Install symlinks
echo "Install symlinks ..."
for s in $tmpdir/* ; do
    [ -d $s ] || continue
    section=${s#$tmpdir/}
    [ -d $installdir/$section ] || mkdir -p $installdir/$section
    for t in $s/* ; do
	[ -d $t ] || continue
	stage=${t#$s/}
	for u in $t/* ; do
	    [ -d $u ] || continue
	    name=${u#$t/}
	    read l < $u/level
	    level=$(printf "%02d" $l)
	    for f in $installdir/$section/*-$name.sh ; do
		if [ -f $f ] ; then
		    case $f in
			*/$level*.sh)
			    break;
			    ;;
			*)
			    rm $f;
			    (cd $installdir/$section; ln -s ../scripts/$section-$name.sh $level-$name.sh)
			    ;;
		    esac
		fi
	    done
	done
    done
done
