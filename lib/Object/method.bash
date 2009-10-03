#!/bin/sh

function usage () {
    printf "SYNOPSIS: ob.method [-v|--verbose|-V|--no-verbose|-h|--help] [method]\n"
    }

# ignore the object in argument $1:
shift

cd $tob_path || exit 1

## if argument is specified, output only that method's full pathname

while test -n "$1"; do
    if test $1 == -v || test $1 == --verbose; then
        VERBOSE=1   
    elif test $1 == -V || test $1 == --no-verbose; then
        unset VERBOSE   
    elif test $1 == -h || test $1 == --help; then
        usage
        exit 0
    elif test ${1#-} != $1; then
        echo unknown option: $1 >&2
        exit 1
    else
        METHOD=$1
    fi
    shift
done

# prepare to scan class directories through ^ or .^ symlinks:
if test -L .^; then
    class=.^
elif test -L ^; then
     class=^
fi

declare -a classlinks
while [ -L $class ]; do
    classlink=$(/bin/readlink -f $class)
    classlinks=($classlinks $classlink)
    if test -L $class/.^; then
        class=$class/.^
    elif test -L $class/^; then
         class=$class/^
    else
        break
    fi
done

for class in ${classlinks[@]}; do
  # echo class: $class
    for f in $class/*; do
        test -d $f && continue
        test -f $f && test -x $f && {
            m=${f##*/} # strip path from method name
            echo $m $f
            }
    done
done |
    awk -vmethod="$METHOD" -vverbose="$VERBOSE" '
        {
        name = $1
        path = $2
        while ( m[name] ) {
            name = "SUPER::" name
            }
        m[name] = 1
        if ( method == name ) {
            print path
            found_method = 1
            }
        else if ( method == "" ) {
            if ( verbose ) 
                print name, path
            else
                print name
            }
        } 
        END {
        if ( method == "" || found_method )
            exit 0
        if ( verbose )
            print method, "not found"
        exit 1
        }
        '

