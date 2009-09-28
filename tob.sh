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

if [ "$ob" == "-h" -o "$ob" == "--help" ]; then
    manpage
    exit 
fi

if [ "$ob" == "-d" -o "$ob" == "--debug" ]; then
    DEBUG=1
    ob=$1
    shift
fi

if [ "$ob" == "-q" -o "$ob" == "--noheader" ]; then
    NOHEADER=1
    ob=$1
    shift
fi

if [ "$ob" == "--nocd" -o "$ob" == "--nochdir" ]; then
    NOCD=1
    ob=$1
    shift
fi

## drop current directory (./) from ob name if present
if [[ "$ob" == ./* ]]; then
    ob=${ob:2}
fi

if [[ ${ob/.*/} == $ob ]]; then # form: tob method object
    method=$ob
    ob=$1
    shift
else # form: tob object.method
    method=$ob
    ob=${ob/.*/}
    method=${method/*./}
fi

if [ "$ob" == "." ]; then # trivial: ignore . and .. files
    exit -1
fi

if [ ${ob/\/*/} != $ob ]; then # split obdir from ob
    obdir=${ob%\/*}
    ob=${ob/*\//}

fi

if [ "$ob" == "." ]; then # trivial: ignore . and .. files
    exit -1
fi

if [ -z "$ob" ]; then # no object parsed 
    exit 2
fi

if [ -z "$method" ]; then # no object parsed 
    exit 3
fi

if [ ! -e $obdir/.$ob ]; then # not a thinobject, so ignore...
    exit -1
fi

test -n "$DEBUG" &&
    echo DEBUG: obdir=$obdir, object=$ob, method=$method, $obdir/$ob.$method

## look for the object's dot-directory:
if [ ! -d $obdir/.$ob ]; then
    echo ERROR: a thinobject foo must have a .foo/ directory
    exit 12
fi

if [ -e $obdir/.$ob/tob ]; then # if tob file/directory/link exists...

    ## require object's tob to be a symlink:
    if [ ! -L $obdir/.$ob/tob ]; then
        echo ERROR: a thinobject foo must have symlink .foo/tob
        exit 13
    fi
    
    if [ -d $obdir/.$ob/tob/ ]; then # tob is a directory
        if [ ! -e $obdir/.$ob/tob/$method ]; then
            echo ERROR: thinobject foo method $method not found
            exit 14
        fi
        if [ ! -x $obdir/.$ob/tob/$method ]; then
            echo ERROR: thinobject foo method $method not executable
            exit 15
        fi
        exec $obdir/.$ob/tob/$method $ob $*
    fi
    
    ## ASSERT: tob symlink is not a directory, so must be executable ob handler
    
    if [ ! -x $obdir/.$ob/tob ]; then
        echo ERROR: thinobject foo handler is not executable
        exit 5
    fi
    
    exec $obdir/.$ob/tob $method $ob $*
    
fi

## ASSERT: no tob file, so handle as base class thinobject

if [ -z $NOHEADER ]; then 
    echo $obdir/$ob: 
fi

if [ "$method" == "ls" ]; then
    if [ -z $NOCD ]; then 
        cd $obdir/.$ob 
        exec ls $* .
    fi
    exec ls $* $obdir/.$ob
fi

if [ "$method" == "find" ]; then
    if [ -z "$NOCD" ]; then 
        cd $obdir/.$ob
        exec find $*
    fi
    exec find $obdir/.$ob $*
fi

if [ "$method" == "class" ]; then
    echo tob
fi

