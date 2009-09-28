#!/bin/sh

# $Header: /home/ken/proj/thinobject/src/sh/../../src-sh/tob.sh,v 1.1 2007/04/03 21:26:22 ken Exp $

# define a special exit status to search up object classes, sub to super(s):
CONTINUE_METHOD_SEARCH=100

# require class handlers & methods to be under this path, unless --not-strict
LIB_ROOT=/usr/local/lib/ThinObject

function manpage() {
    cat <<END_MANPAGE
NAME

tob -- thinobject enabler 

SYNOPSIS

  $ tob OPTIONS object.method args...

DESCRIPTION

*thinobject* is an experimental system aimed at implementing object
oriented behaviors directly on a (unix) filesystem.  A thinobject is a
file or directory with an associated hidden directory of the same name
but with a "dot" prefix.

The object hidden directory can contain arbitrary files (i.e., properties)
and directories.

The object hidden directory may contain a symlink, "ISA", which points to
a "class handler" for the object, or to a "class directory" containing
object methods.  A class directory may contain a symlink, "SUPER",
to a parent class directory or handler.

Class handlers and methods can use a special exit status value ($CONTINUE_METHOD_SEARCH)
to tell tob.sh to keep searching for method handlers.  Searching will
fall through to the "base class" methods defined in this program, tob.sh.

OPTIONS

  -h, --help
    display manpage

  -S, --not-strict
    suppress checking of class/method handler location

  --nocd
    don't change to the object hidden directory

  -m method 
  --method METHOD
    apply method to each argument object

  -v, --verbose
    show object name before other output

  -d, --debug
    print debugging information
    --debug + --verbose also shows commands to be run for base methods

DEFAULT METHODS

tob 
  print (expose) path to the object hidden store (directory)
  (note; this method cannot be subclassed)

exists
  return true if the object is a *thinobject*

ls [args]
  apply shell C<ls> command to object hidden store

find [args]
  apply shell C<find> command to object hidden store

cat property ...
  print property content to STDOUT

set property [content]
  overwrite the object property with arguments or from STDIN

isa 
  print object class

new [class]
  create empty object and hidden store
  class must exist under LIB_ROOT ($LIB_ROOT) unless --not-strict is set

clone object2
  create new object as copy of object2

edit [options] property ...
  invoke system editor to edit selected properties

AUTHOR

copyright (c) 2006 Ken Irving <fnkci@uaf.edu>
the author intends this code to be licensed under the GNU Public License (GPL)

END_MANPAGE
    };

function bail () {
    echo $* >&2
    exit 1
    }

ob=$1
shift
while [ -n "$ob" -a ${ob#-} != $ob ]; do # option detected by leading "-" ...

    if [ "$ob" == "-d" -o "$ob" == "--debug" ]; then
        DEBUG=1
        opt="$opt -d"

    elif [ "$ob" == "-v" -o "$ob" == "--verbose" ]; then
        VERBOSE=1
        SHOWHEADER=1
        opt="$opt -v"

    elif [ "$ob" == "-m" -o "$ob" == "--method" ]; then
        method=$1
        shift
        test $method || bail "no method argument"

    elif [ "$ob" == "-a" -o "$ob" == "--arg" ]; then
        args="$args $1"
        shift

    elif [ "$ob" == "-S" -o "$ob" == "--not-strict" ]; then
        NOT_STRICT=1
        opt="$opt -S"

    elif [ "$ob" == "--nocd" ]; then
        NOCD=1
        opt="$opt --nocd"

    elif [ "$ob" == "-h" -o "$ob" == "--help" ]; then
        manpage
        exit 0
    
    else
        bail "unsupported option $ob"
    fi
    ob=$1 # try again...
    shift
done

test -z $ob && bail "no object specified"

test $method && { # iterate same method on multiple objects
    while [ $ob ]; do
        if [ ${ob/=} != $ob ]; then # tag=value form detected
            args="$args $ob"
        else
            test $VERBOSE && echo tob $opt $ob.$method $args
            tob $opt $ob.$method $args || bail "failed in $ob.$method"
        fi
        ob=$1
        shift
    done
    exit 0
    }

test ${ob#./} != $ob && ob=${ob:2} # drop leading ./ from ob name if present

if [[ ${ob/./} == $ob ]]; then # no dot in ob, so no method specified
    method=exists
else # parse object.method:
    method=$ob
    method=${method#*.} # method follows "."
    ob=${ob%.*}         # object precedes "."
fi

test -z $ob && bail "no object parsed, method $method"

test -z $method && bail "no method parsed, object $ob"

## ASSERT: ob and method have been parsed, but not checked

test ! -e $ob && { # object not found; check for new or clone methods
    ## ASSERT: ob does not exist
    test "$method" != "new" -a "$method" != "clone" &&
        bail "$ob object not found"

    ## ASSERT method new() or clone()
    if [ ${ob/\/} == $ob ]; then # no slash in ob
        dob=.$ob
    else # ob has a slash in it
        dob=${ob%\/*}/.${ob/*\//}
    fi
    test -e "$dob" &&
        bail "no object $ob found, but hidden store $dob already exists!??"
    test $VERBOSE && echo object: $ob, hidden store: $dob

    test "$method" == "new" && {
        test -n "$1" && { # class specified as argument
            isa=$1
            if [ ${isa#/} != $isa ]; then # absolute path
                test ! "$NOT_STRICT" -a ${isa#$LIB_ROOT} == $isa &&
                    bail "ERROR new: invalid class library path"
            else # relative path
                isa=$LIB_ROOT/$isa
            fi
            test ! -e $isa &&
                bail "ERROR new: class library $isa not found"
            ## should perhaps do more validity testing of the class here
            }
        test $VERBOSE && echo creating new object $ob
        touch $ob
        mkdir $dob
        test $isa && ln -s $isa $dob/ISA
        test -x $dob/ISA/new && exec tob $ob.new
        exit 0
        }

    ## ASSERT: method clone()

    ob2=$1
    shift

    test -z "$ob2" &&
        bail "ERROR clone: need to specify object to clone"

    if [ -n "$1" ]; then $ob2=$1; else
        bail "need to specify object to clone"
    fi

  # echo resolve $ob2 and its hidden store
    ## resolve symlink to target if linked
    test -L $ob2 && dob=$(readlink -f $ob2) # resolve symlinked/aliased ob2

    if [ ${ob2/\/*/} == $ob2 ]; then # no slash in ob2
        dob2=.$ob2
    else # ob2 has a slash in it
        dob2=${ob2%\/*}/.${ob2/*\//}
    fi

    test ! -d "$dob2" &&
        bail "$ob2 is not a thinobject \(no hidden store $dob2\)"

    echo cloning $ob2 to $ob
    cp -p $ob2 $ob
    cp -rp $dob2 $dob
    exit 0
    }

## ASSERT: object ob exists

dob=$ob
test -L $dob && dob=$(readlink -f $dob) # resolve symlinked/aliased ob

## ASSERT: $dob should be paired with a dot-directory in same directory

if [ ${dob#*/} == $dob ]; then # no slash in ob
    dob=.$dob
else # dob has a slash in it
  # dob=${dob%\/*}/.${dob/*\//}
    dob=${dob%/*}/.${dob##*/}
fi

## ASSERT: $ob is an object, $dob its hidden store

test -z "$ob" -o -z "$dob" && exit 1 # no object was parsed 

test ! -d $dob && # no dot-directory found
    bail "ERROR: object $ob hidden store $dob is not a directory"

## ASSERT ob is a thinobject, dob is the hidden store

test -n "$DEBUG" &&
    echo DEBUG: object=$ob, method=$method, args1=\'$args\' args2=\'$*\'

test -z "$method" &&
    bail "SHOULDN\'T HAPPEN -- no method specified for $ob"

## SPECIAL CASES: tob and isa methods precede the normal method search
test "$method" == "tob" && {
    test -z "$*" && echo $dob
    for arg in $*; do
        echo $dob/$arg
    done
    exit 0
    }

test "$method" == "isa" && {
    test -e $dob/ISA && {
        test -L $dob/ISA && {
            ls -l $dob/ISA | awk -v s=$LIB_ROOT '{
                sub(s, "", $NF); # remove lib_root from link target
                sub("^/+", "", $NF); # remove leading & trailing "/"
                sub("/+$", "", $NF);
                print $NF
                }'
            superclass=$dob/ISA/SUPER
            pad="    "
            while [ -L $superclass ]; do
                readlink -f $superclass | awk -v s=$LIB_ROOT -v pad="$pad" '{
                    sub(s, "", $NF); # remove lib_root from link target
                    sub("^/+", "", $NF); # remove leading & trailing "/"
                    sub("/+$", "", $NF);
                    print pad $NF
                    }'
                superclass=$superclass/SUPER
                pad="    "$pad
            done
            exit 0
            }
        bail "$ob ISA property is not a symlink..."
        }
    ## ASSERT: no object class specified, so the default is:
    echo thinobject
    exit 0
    }

## ASSERT a method was passed

test -e $dob/ISA && { # object ISA file/directory/link exists...

    ## not sure the following test is really required or valid...
    ##    e.g., one could have a once-only object I suppose ...
    ## require object's ISA to be a symlink:
    test ! -L $dob/ISA &&
        bail "ERROR: object $ob ISA property is not a symlink"

    test -z $NOT_STRICT && { # safety check
      # test $VERBOSE && echo CHECKING: $(ls -l $dob/ISA)
        ls -l $dob/ISA | awk -v s=$LIB_ROOT 'index($NF,s)!=1{exit(1)}' ||
            bail "invalid class/method handler location"
        }

    isa=$dob/ISA
    while [ -e $isa ]; do
        ## ASSERT: parent class exists
        if [ -d $isa ]; then # parent class methods directory
            test -e $isa/$method && { # method found!
                if [ -x $isa/$method ]; then
                    # call object method handler, grab exitcode
                    $isa/$method $ob $args "$@"
                    exitcode=$?
                else
                    ## suspect this may also happen due to permissions...
                    ## ... so may need to rethink this simple bail-out
                    bail "ERROR: super object method $method not executable"
                fi
                }
        else ## monolithic parent class handler
            if [ -x $isa ]; then ## handler is executable
                # invoke handler, grab exitcode
                $isa $method $ob $args "$@"
                exitcode=$?
            else
                ## as noted above, not sure if this bail-out is right to do...
                bail "ERROR: $isa handler not executable"
            fi
        fi
        test -n "$exitcode" && { # method handler was run, and returned
            ## continue only if special exit status value is returned
            ## note that exit status of 0 will also apply here...
            test $exitcode == $CONTINUE_METHOD_SEARCH || exit $exitcode
            }
        ## ASSERT: method either not found or handler says to keep going...
        isa=$isa/SUPER # continue search with parent class, if any...
    done

    }

## ASSERT: no ISA file, so handle as base class thinobject

## default methods follow

test -n "$SHOWHEADER" && echo $ob: 

test "$method" == "exists" && {
    test $VERBOSE && echo object $ob exists
    exit 0
    }

test "$method" == "ls" && {
    if [ -z $NOCD ]; then
        cd $dob
        target="$@"
    else
        target="$dob/$@"
    fi
  # test $DEBUG -a $VERBOSE && echo exec ls -p $args $target
    exec ls -p $args $target
    }

test "$method" == "wc" && {
    if [ -z $NOCD ]; then
        cd $dob
        target="$*"
    else
        target="$dob/$*"
    fi
  # test $DEBUG -a $VERBOSE && echo exec wc -p $args $target
    exec wc $args $target
    }

test "$method" == "find" && {
    test -z "$NOCD" && {
        cd $dob
        if [ -n "$*" ]; then
          # exec find -L $* # follow symlinks by default!
            test $DEBUG -a $VERBOSE && echo exec find -follow $*
            exec find -follow $* # follow symlinks by default!
        else # by default, show output without leading "./"
          # exec find -L -printf "%P\n"
            test "$DEBUG" -a "$VERBOSE" && echo exec find -follow -printf "%P\n"
            exec find -follow -not -type d -printf "%P\n"
        fi
        }
    test $DEBUG -a $VERBOSE && echo exec find $dob $*
    exec find $dob $*
    }

test "$method" == "cat" && {
    if [ -z $NOCD ]; then
        cd $dob
        target="$*"
    else
        target="$dob/$*"
    fi
    for prop in $target; do
        if [ -e $prop ]; then
            test $VERBOSE && echo $prop:
            cat $prop
        else
            bail "ERROR: no property $prop"
        fi
    done
    exit 0
    }

test "$method" == "set" && {
    prop="$1"
    shift
    test ! -e $dob/$prop && bail "ERROR: no property $prop"
    if [ -n "$1" ]; then
        exec echo "$*" > $dob/$prop
    else
        exec cat > $dob/$prop
    fi
    }

test "$method" == "param" && {
    tag="$1"
    shift
    value="$1"
    shift
    cd $dob
    test -z "$tag" && { # list all parameters
        for f in *\=*; do echo $f; done
        exit 0
        }
    test -n "$value" && { # set parameter value
        test -e $tag\=* && rm $tag\=* 
        touch $tag\=$value
        }
    ## ASSERT: $tag is defined -- but may or may not exist
    test ! -e $tag\=* && exit 1
    exec ls $tag\=*
    }

test "$method" == "edit" && {
    if [ -z $NOCD ]; then
        cd $dob
        target="$*"
    else
        for f in $*; do
            if [ $f == ${f#-} ]; then
                target="$target $dob/$f"
            else
                target="$target $f"
            fi
        done
    fi
    test $VERBOSE && echo editor $target
    editor $target
    exit 0
    }

test "$method" == "delete" && { ## CAUTION!!
    if [ -z "$*" ]; then # no args, so delete object
        rmdir $dob || bail 
        rm $ob
    else
        for f in $*; do
            property=$dob/$f
            test "$VERBSOSE" && echo delete property $property
            if [ -f $property ]; then   # ordinary file
                rm $property
            elif [ -L $property ]; then # symlink
                rm $property
            else                        # directory
                rmdir $property || bail "$property directory not empty"
            fi
        done
    fi
    exit 0
    }

test $VERBOSE && echo no method $method found 
bail "no method $method found"
