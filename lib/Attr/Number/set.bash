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

num=$1

# split number on decimal point:
unset frac
int=${num%.*}
test -n "$int" && int=0
test "$int" = "$num" || frac=${num#*.}

test $int -eq $int 2>/dev/null ||
    error --exit 2 "non-numeric argument: $num -- integer part"

test -n "$frac" && {
    test $frac -eq $frac 2>/dev/null ||
        error --exit 2 "non-numeric argument: $num -- fractional part"
    test $frac -ge 0 || 
        error --exit 2 "non-numeric argument: $num -- negative fractional part"
    }

test -n "$NUM_MIN" && { test $NUM_MIN -le $int ||
    error --exit 3 "$num is less than NUM_MIN=$NUM_MIN"
    }

test -n "$NUM_MAX" && { test $int -le $NUM_MAX ||
    error --exit 4 "$num is greater than NUM_MAX=$NUM_MAX"
    }

TOB_resolve_method_path super.set &&
    exec $TOB_method_path $num

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

