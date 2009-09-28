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

  -v
  --verbose
    show object name before other output

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

ob=$1
shift

NOHEADER=1

test "$ob" == "-h" -o "$ob" == "--help" && {
    manpage
    exit 1
    }

test "$ob" == "-d" -o "$ob" == "--debug" && {
    DEBUG=1
    ob=$1
    shift
    }

# test "$ob" == "-q" -o "$ob" == "--noheader" && {
#     NOHEADER=1
#     ob=$1
#     shift
#     }

test "$ob" == "-v" -o "$ob" == "--verbose" && {
    VERBOSE=1
    unset NOHEADER
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

[[ "$ob" == ./* ]] && ob=${ob:2} # drop leading ./ from ob name if present

if [[ ${ob/.*/} == $ob ]]; then # form: tob method object
    if [ -n "$1" ]; then
        method=$ob
        ob=$1
        shift
    fi
else # form: tob object.method
    method=$ob
    method=${method/*./} # method follows "."
    ob=${ob/.*/}         # object precedes "."
    test ${ob%/} != $ob && { # object is null
        echo error: invalid object
        exit -1
        }
fi

test "$ob" == "." && { # trivial: ignore . and .. files
    exit -1
    }

## ASSERT: ob and method have been parsed, but not checked

test ! -e $ob && {
    ## ASSERT: ob does not exist
    if [ "$method" != "new" -a \
         "$method" != "clone" ]; then
        echo $ob object not found
        exit 1
    fi
    ## ASSERT method new() or clone()
    if [ ${ob/\/*/} == $ob ]; then # no slash in ob
        dob=.$ob
    else # ob has a slash in it
        dob=${ob%\/*}/.${ob/*\//}
    fi
    test -e "$dob" && {
        echo $ob\'s hidden store $dob already exists!?? 
        exit 1
        }
    test $VERBOSE && echo object: $ob, hidden store: $dob

    test "$method" == "new" && {
        echo creating new object $ob
        touch $ob
        mkdir $dob
        exit 0
        }

    ## ASSERT: method clone()

    if [ -n "$1" ]; then $ob2=$1; else
        echo need to specify object to clone 
        exit 1
    fi

  # echo resolve $ob2 and its hidden store
    ## resolve symlink to target if linked
    test -L $ob2 && dob=$(readlink -f $ob2) # resolve symlinked/aliased ob2

    if [ ${ob2/\/*/} == $ob2 ]; then # no slash in ob2
        dob2=.$ob2
    else # ob2 has a slash in it
        dob2=${ob2%\/*}/.${ob2/*\//}
    fi

    test ! -d "$dob2" && {
        echo $ob2 is not a thinobject \(no hidden store $dob2\)
        exit 1
        }

    echo cloning $ob2 to $ob
    cp -p $ob2 $ob
    cp -rp $dob2 $dob
    exit 0
    }
## ASSERT: the file or directory ob exists

dob=$ob
test -L $dob && dob=$(readlink -f $dob) # resolve symlinked/aliased ob

## ASSERT: $dob should be paired with a dot-directory in same directory

if [ "${dob/\//}" == $dob ]; then # no slash in ob
    dob=.$dob
else # dob has a slash in it
    dob=${dob%\/*}/.${dob/*\//}
fi

## ASSERT: $ob is an object, $dob its hidden store

test -z "$ob" && exit 2 # no object was parsed 

## I don't think the following test is needed...
## test "$ob" == "." && exit -1 # trivial: ignore . and .. files

test -z "$dob" && exit 2 # no object parsed 

test ! -d $dob && { # no dot-directory found
    echo ERROR: no dot-directory found, so $ob is not an object
    exit 12
    }

## ASSERT ob is a thinobject, dob is the hidden store

test -n "$DEBUG" &&
    echo DEBUG: object=$ob, method=$method, $ob.$method

test -z "$method" && { ## no method was specified
    ## return true because the argument object is a thinobject
    exit 0
    }

## ASSERT a method was passed

test -e $dob/tob && { # if tob file/directory/link exists...

    ## require object's tob to be a symlink:
    test ! -L $dob/tob && {
        echo ERROR: a thinobject foo must have symlink .foo/tob
        exit 13
        }
    
    test -d $dob/tob/ && { # tob is a directory
        test ! -e $dob/tob/$method && {
            echo ERROR: thinobject foo method $method not found
            exit 14
            }
        test ! -x $dob/tob/$method && {
            echo ERROR: thinobject foo method $method not executable
            exit 15
            }
        exec $dob/tob/$method $ob $*
        }
    
    ## ASSERT: tob symlink is not a directory, so must be executable ob handler
    
    test ! -x $dob/tob && {
        echo ERROR: thinobject foo handler is not executable
        exit 5
        }
    
    exec $dob/tob $method $ob $*
    
    }

# echo args: $*

## ASSERT: no tob file, so handle as base class thinobject

test -z $NOHEADER && echo $ob: 

# test "$method" == "ls" && {
#     test -z $NOCD && {
#         cd $dob 
#         exec ls $* .
#         }
#     exec ls $* $dob

test "$method" == "ls" && {
    test -z $NOCD && {
        cd $dob 
        exec ls -p $* 
        }
    if [ -z "$*" ]; then 
      # echo exec ls $dob
        exec ls -p $dob
    else
        for arg in $*; do
          # echo ls $dob/$arg...
            ls -p $dob/$arg
        done
    fi
    }

test "$method" == "find" && {
    test -z "$NOCD" && {
        cd $dob
        exec find $*
        }
    exec find $dob $*
    }

# test "$method" == "class" && echo tob

test "$method" == "class" && {
    test -z $NOOUTPUT && echo tob
    exit 0
    }

test "$method" == "cat" && {
    test -z $NOCD && {
        cd $dob 
        for arg in $*; do
            cat $arg
        done
        exit 0
        }
    ## 
    if [ -z "$*" ]; then 
        exec cat $ob
    else
        for arg in $*; do
            cat $dob/$arg
        done
      # for arg in $dob/$*; do
      #     arg=$dob/$arg
      #     echo cat $arg:
      #   # cat $arg
      # done
    fi
    }

test "$method" == "path" && {
    test -z "$*" && echo $dob
    for arg in $*; do
        echo $dob/$arg
    done
    }

test "$method" == "get" && {
    prop="$1"
    test ! -e $dob/$prop && {
        echo ERROR: no property $prop
        exit 1
        }
    cat $dob/$prop
    }

test "$method" == "set" && {
    prop="$1"
    test ! -e $dob/$prop && {
        echo ERROR: no property $prop
        exit 1
        }
    cat > $dob/$prop
    }

exit 0
