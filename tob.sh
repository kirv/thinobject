#!/bin/sh

function manpage() {
    cat <<END_MANPAGE
NAME

tob -- thinobject enabler 

SYNOPSIS

  $ tob OPTIONS object.method args...

  $ tob OPTIONS method object args...

DESCRIPTION

*thinobject* is an experimental system aimed at implementing object oriented
behaviors directly on a (unix) filesystem.  A thinobject is a file or directory
with an associated hidden directory of the same name but with a "dot" prefix.

In addition, the hidden directory may contain a symlink, "tob", which points to 
a handler for the object, or to a directory containing object methods.

OPTIONS

  -h
  --help
    display manpage

  -d
  --debug
    print debugging information

  -q
  --noheader
    suppress showing object name (and ending colon)

  --nocd
  --nochdir
    don't change to the object hidden directory

BASE METHODS

If no other object methods are found, i.e., no F<tob> file is defined for the
object, methods C<ls> and C<find> are provided as wrappers for those shell 
commands.

ls
Arguments must all have a leading dash, since the method becomes:

  ls args object

where "object" here is actually the object's hidden directory.

find
Arguments are all simply passed to find in natural order, e.g.:

  find object args

AUTHOR

Ken Irving <fnkci@uaf.edu>

END_MANPAGE
    };

obdir=./
ob=$1
shift

test "$ob" == "-h" -o "$ob" == "--help" && {
    manpage
    exit 1
    }

test "$ob" == "-d" -o "$ob" == "--debug" && {
    DEBUG=1
    ob=$1
    shift
    }

test "$ob" == "-q" -o "$ob" == "--noheader" && {
    NOHEADER=1
    ob=$1
    shift
    }

test "$ob" == "-s" -o "$ob" == "--silent" && {
    NOOUTPUT=1
    NOHEADER=1
    ob=$1
    shift
    }

test "$ob" == "--nocd" -o "$ob" == "--nochdir" && {
    NOCD=1
    ob=$1
    shift
    }

## resolve symlink object to actual object name

[[ "$ob" == ./* ]] && ob=${ob:2} # drop leading ./ from ob name if present

if [[ ${ob/.*/} == $ob ]]; then # form: tob method object
    method=$ob
    ob=$1
    shift
else # form: tob object.method
    method=$ob
    ob=${ob/.*/}
    method=${method/*./}
fi

test "$ob" == "." && { # trivial: ignore . and .. files
    exit -1
    }

# if [ -L $ob ]; then
#     echo $ob is a symlink
#     symob=$(ls -l bullen/kvr | awk '{print $NF}')
#     echo symob is $symob
# fi

test -L "$ob" && symob=$(ls -l bullen/kvr | awk '{print $NF}')

test ${ob/\/*/} != $ob && { # split obdir from ob
    obdir=${ob%\/*}
    ob=${ob/*\//}
    test -n "$symob" && ob=$symob
    }

test "$ob" == "." && exit -1 # trivial: ignore . and .. files

test -z "$ob" && exit 2 # no object parsed 

test -z "$method" && exit 3 # no object parsed 

test ! -e $obdir/.$ob && exit -1 # not a thinobject, so ignore...

test -n "$DEBUG" &&
    echo DEBUG: obdir=$obdir, object=$ob, method=$method, $obdir/$ob.$method


test ! -d $obdir/.$ob && { # no dot-directory found
    echo ERROR: a thinobject foo must have a .foo/ directory
    exit 12
    }

test -e $obdir/.$ob/tob && { # if tob file/directory/link exists...

    ## require object's tob to be a symlink:
    test ! -L $obdir/.$ob/tob && {
        echo ERROR: a thinobject foo must have symlink .foo/tob
        exit 13
        }
    
    test -d $obdir/.$ob/tob/ && { # tob is a directory
        test ! -e $obdir/.$ob/tob/$method && {
            echo ERROR: thinobject foo method $method not found
            exit 14
            }
        test ! -x $obdir/.$ob/tob/$method && {
            echo ERROR: thinobject foo method $method not executable
            exit 15
            }
        exec $obdir/.$ob/tob/$method $ob $*
        }
    
    ## ASSERT: tob symlink is not a directory, so must be executable ob handler
    
    test ! -x $obdir/.$ob/tob && {
        echo ERROR: thinobject foo handler is not executable
        exit 5
        }
    
    exec $obdir/.$ob/tob $method $ob $*
    
    }

## ASSERT: no tob file, so handle as base class thinobject

test -z $NOHEADER && echo $obdir/$ob: 

test "$method" == "ls" && {
    test -z $NOCD && {
        cd $obdir/.$ob 
        exec ls $* .
        }
    exec ls $* $obdir/.$ob
    }

test "$method" == "find" && {
    test -z "$NOCD" && {
        cd $obdir/.$ob
        exec find $*
        }
    exec find $obdir/.$ob $*
    }

# test "$method" == "class" && echo tob

test "$method" == "class" && {
    test -z $NOOUTPUT && echo tob
    exit 0
    }

