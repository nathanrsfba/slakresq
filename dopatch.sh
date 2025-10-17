#!/bin/sh

main() {
    local patchfile="$1"
    local patchdir="`dirname "$patchfile"`"

    echo "$patchfile"

    TMP="`mktemp -dt srpatch.$$.XXXXXXXX`" || exit 1
    trap cleanup EXIT

    cutpatch "$patchfile" "$TMP"
    cut=$?
    
    # Path to patch header
    local head
    # Path to patch contents
    local patch

    if [ $cut = 0 ]; then
        # echo "Cut."
        export head="$TMP/head"
        export patch="$TMP/patch"
    else
        # echo "External."
        export head="$patchfile"
        export patch=/dev/null
    fi


    local tree
    local path
    local dir
    local from
    local replace
    local dest=patches
    local external
    local type
    local chmod
    local owner
    local group

    local base="`basename "$patchfile"`"
    base="${base%.*}"

    . "$head"

    if [ "$path$dir" = "" ]; then
        echo "path or dir is required"
        exit 1
    fi
    if [ "$external" != "" ]; then
        patch="$patchdir/$external"
    fi

    if [ "$dir" != "" ]; then
        path="$dir/$base"
    fi

    head="`realpath "$head"`"
    patch="`realpath "$patch"`"

    # Location of original file, relative to generated root
    orig="$path"
    if [ "$from" != "" ]; then
        orig="$from"
    fi
    if [ "$replace" != "" ]; then
        orig="$replace"
    fi

    if [ "$dest" = orig -a "$tree" = "" ]; then
        echo 'dest=orig requires tree to be set'
        exit 1
    fi

    # Path to the given tree, relatve to slakresq build tree
    local sourceroot
    if [ "$tree" != "" ]; then
        if [ "$tree" = "base" ]; then
            sourceroot="$tree"
        else
            sourceroot="trees/$tree"
        fi
        sourceroot="`realpath "$sourceroot"`"
    fi
    local sourcepath="$sourceroot/$orig"
    local origpath="$sourcepath"

    # Path to the destination tree
    local destroot="trees/99-patches"
    if [ "$dest" = "orig" ]; then
        destroot="$sourceroot"
        if [ "$from$replace" = "" ]; then
            cp "$sourcepath" "$TMP/orig"
            sourcepath="$TMP/orig"
        fi

    fi
    destroot="`realpath "$destroot"`"


    local destpath="$destroot/$path"
    echo "Patch header: $head"
    echo "Patch body: $patch"
    echo "File base: $base"
    echo "Target path: $path"
    echo "Source path: $orig"
    echo "Physical source root: $sourceroot"
    echo "Physical source path: $sourcepath"
    echo "Physical target root: $destroot"
    echo "Physical target path: $destpath"
    
    mkdir -p "`dirname "$destpath"`"

    case "$type" in
        patch)
            patch "$sourcepath" "$patch" -o "$destpath" || exit 1
            ;;
        new) 
            cp "$patch" "$destpath" || exit 1
            ;;
        prepend)
            if grep -q '^#!' "$sourcepath"; then
                head -1 "$sourcepath" > "$destpath" || exit 1
                cat "$patch" >> "$destpath" || exit 1
                tail -n +2 "$sourcepath" >> "$destpath" || exit 1
            else
                cat "$patch" "$sourcepath" > "$destpath" || exit 1
            fi
            ;;
        append)
            cat "$sourcepath" "$patch" > "$destpath" || exit 1
            ;;
        script) ;;
        copy)
            cp -a "$sourcepath" "$destpath" || exit 1
            ;;
        tar)
            mkdir -p "$destpath"
            tar -C "$destpath" -x -f "$patch" || exit 1
            ;;
        delete) ;;
        link) ;;
        *)
            echo "Unknown patch type: $type"
            exit 1
            ;;

    esac

}

cleanup() {
    # echo "Removing temp files... $TMP"
    rm -rf "$TMP"
}

# Cut the patch in the file into the patch header and the contents.
# Pieces will be placed in $1/head and $1/patch.
#
# If no contents are present, returns 1 and doesn't split
#
# $1: Patch file
# $2: Temp directory
cutpatch() {
    grep -Eq '^-+$' "$1" || return 1
    (
    while read line; do
        if [ "${line##*-}" = "" ]; then
            break
        fi
        echo $line >> "$2/head"
    done

    cat >> "$2/patch"
    ) < "$1"
}

main "$1"
