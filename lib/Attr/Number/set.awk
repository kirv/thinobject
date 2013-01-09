#!/bin/bash

synopsis="Attr/Number.set VALUE"

error() {
    exitvalue=1
    test -n "$1" -a $1 = --exit && shift && exitvalue=$1 && shift
    printf "%s\n" "$@" >&2
    exit $exitvalue
    }

test -n "$1" ||
    error --exit 1 "required numeric argument missing"

opts="-vnum=$1"
test -n "$NUM_PREC" && opts="$opts -vprec=$NUM_PREC"

declare -a script=()
test -n "$NUM_MIN" && script+=("min $NUM_MIN")
test -n "$NUM_MAX" && script+=("max $NUM_MAX")

storevalue=$( printf "%s\n" "${script[@]}" | gawk $opts '
    $1 == "min" { if (num<$2) x=3 }
    $1 == "max" { if (num>$2) x=4 }
    END {if (x>0)
            exit x
        else
            if (prec>0)
                printf("%.2$f\n", prec, num)
            else
                print num
        }') || exit

TOB_resolve_method_path super.set &&
    exec $TOB_method_path $storevalue

exit
    
NAME
    Attr/Number.set -- set numeric attribute to given value

SYNOPSIS
    Attr/Number.set VALUE

EXIT VALUES
    1 -- required argument is missing
    2 -- argument is not a number
    3 -- argument is less than NUM_MIN value
    4 -- argument is greater than NUM_MAX value
    
DESCRIPTION
    Argument value is split on decimal point and each half tested
    separately as integers.

BUGS
    This code should be replaced by something, e.g., using bc or
    python, awk, etc.

    Validation is simplistic, with the argument split on the decimal
    point and the integer and fractional parts tested separately.

    Some awkward or invalid forms will be accepted:

        045, 45., +5.
        0.+3

AUTHOR
    ken.irving@alaska.edu (c) 2011

