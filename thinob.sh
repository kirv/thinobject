#!/bin/sh

# define a special exit status to search up object classes, sub to super(s):
CONTINUE_METHOD_SEARCH=100

# require class handlers & methods to be under this path, unless --not-strict
LIB=( ~/lib /usr/local/lib /usr/lib )
ROOT=( thinob tob ThinObject )

function check_class () {
    local class="$1"
    for lib in ${LIB[@]}; do
        for root in ${ROOT[@]}; do
            path=$lib/$root
            test ${class#$path/} == $class || { # got it!
                return 0
                }
        done
    done
    return 1
    }

function classname () { # remove class library root from class link ^
    classname=$1
    for lib in ${LIB[@]}; do
        for root in ${ROOT[@]}; do
            path=$lib/$root
            test ${classname#$path/} == $classname || {
                classname=${classname#$path/}
                return 0
                }
        done
    done
    return 1
    }

function bail () { echo $* >&2; exit 1; }

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

    elif [ "ob" == "-H" -o "$ob" == "--not-hidden" ]; then
        ## with new or clone methods, create object directly, not dotted...
        NOT_HIDDEN=1
        opt="$opt --not-hidden"

    elif [ "ob" == "-T" -o "$ob" == "--no-touch" ]; then
        ## with new or clone methods, create hidden ob, don't 'touch' nominal
        NO_TOUCH=1
        opt="$opt --no-touch"

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

test $method && { # iterate method on multiple objects (see -m, --method)
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

# ASSERT: $ob contains object(s) and method
# echo START: $ob

function resolve_ob_to_tob () { # return object path in global var tob:
  # tob="${1}__"
    ob=$1
    test -L $ob && ob=$(readlink -f $ob) # resolve symlinked/aliased ob

    ## ASSERT: $ob is NOT a symlink, so is either a file, directory, or null

    if [ -d $ob -a -e "$ob/^" ]; then # $ob is a thinobject (but not checked)
        tob=$ob
        return
    fi
    ## ASSERT: $ob itself is not a thinobject, so check the dot-object...

    if [ "${ob/\/*/}" == "$ob" ]; then # no slash in ob
        tob=.$ob
    else # ob has a slash in it
        tob=${ob%\/*}/.${ob/*\//}
    fi
    test -L $tob/^ && return # tob is a thinobject
    bail "$1 ($ob) is not a thinobject"
    }

####################
## check for & resolve colon-delimited (contained) objects to the final object:
####################

test ${ob/::} == $ob || bail double colons not supported... need to fix?

# ## replace any '::' sequences temporarily:
# ob=${ob//::/__2COLONS__}
while [ ${ob/:/} != $ob ]; do
  # echo .
    oball=$ob
    ob=${ob%%:*}
    oblist=${oball#*:}

    # ## restore double colon in ob
    # ob=${ob//__2COLONS__/::}
   
  # echo RESOLVE: $ob
  # echo REMAINS: $oblist

  # echo resolve $ob to tob

    resolve_ob_to_tob $ob

    ob=$tob/$oblist

    # ## encode double colon in ob
    # ob=${ob//::/__2COLONS__}
  # echo _TEST: $ob

    done

# ob=${ob//__2COLONS__/::}

# echo _DONE: $ob

####################
## now parse method from object
####################

method=${ob##*.}
ob=${ob%.*}

# echo .
# echo OBJECT: $ob
# echo METHOD: $method

test -z $ob && bail "no object parsed, method $method"

test -z $method && bail "no method parsed, object $ob"

## ASSERT: ob and method have been parsed, but not checked

# echo "    DEBUG: ob: $ob"
# echo "    DEBUG: method: $method"

if [ $method == 'new' -o $method == 'clone' ]; then

    echo DEBUG: about to create new object: $ob

    if [ $NOT_HIDDEN ]; then
        test -e $ob && bail "$ob already exists as file or directory"
        ## ASSERT: $ob does not exist
        tob=$ob
    else
        ## create tob by "dotting" ob:
        if [ ${ob/\/} == $ob ]; then # no slash in ob
            tob=.$ob
        else # ob has a slash in it
            tob=${ob%\/*}/.${ob/*\//}
        fi
    fi

  # echo nominal: $ob
  # echo _object: $tob
  # echo _method: $method

    test -e "$tob" && bail "thinobject $tob already exists!??"

    test "$method" == "new" && {
        class="$1"; shift
        test -n $class || bail "no thinobject class specified!" 
        ## ASSERT class is specified

        if [ ${class#/} != $class ]; then # absolute path
            test ! "$NOT_STRICT" && 
                check_class $class || bail "ERROR new: invalid class library path"
        else # relative path
            unset classpath
            for lib in ${LIB[@]}; do
                for root in ${ROOT[@]}; do
                    echo CHECKING: $lib/$root/$class...
                    test -x $lib/$root/$class && {
                        classpath=$lib/$root/$class
                        test -f $classpath || test -d $classpath ||
                            bail "ERROR new: $class not directory or handler"
                        break 2
                        }
                done
            done
            test -z "$classpath" &&
                bail "ERROR new: class library $class not found"
            class=$classpath
        fi
        test ! -e $class &&
            bail "ERROR new: class library $class not found"
        ## should perhaps do more validity testing of the class here

        test $VERBOSE && echo creating new object $ob
        test ! $NO_TOUCH && touch $ob
        mkdir $tob
        ln -s $class $tob/^
        test -x $tob/^/new || exit 0 # no new method
        $tob/^/new $tob "$@" && exit 0 # all done!
        ## ASSERT: the ob.new method failed, so clean up
        exec thinob $ob.delete
        }

    test "$method" == "clone" && {
        ob2=$1
        shift

        bail clone method not supported yet!

        ## need to check out the following bits...
    
        test -z "$ob2" &&
            bail "ERROR clone: need to specify object to clone"
    
      # echo resolve $ob2 and its hidden store
        ## resolve symlink to target if linked
        test -L $ob2 && tob2=$(readlink -f $ob2) # resolve symlinked/aliased ob2
    
        if [ ${ob2/\/*/} == $ob2 ]; then # no slash in ob2
            tob2=.$ob2
        else # ob2 has a slash in it
            tob2=${ob2%\/*}/.${ob2/*\//}
        fi
    
        test ! -d "$tob2" &&
            bail "$ob2 is not a thinobject \(no hidden store $tob2\)"
    
        test $VERBOSE && echo cloning $ob2 to $ob
        cp -p $ob2 $ob
        cp -rp $tob2 $tob
        exit 0
        }
    bail "shouldn't get here..."
fi ## end of new or clone section

# echo .
# echo OBJECT: $ob
# echo METHOD: $method

resolve_ob_to_tob $ob
# echo ___TOB: $tob

###########################################################333

## ASSERT: $ob is a nominal object, $tob is the actual thinobject

test -z "$ob" -o -z "$tob" && bail "no object was parsed"

test ! -d $tob && bail "ERROR: $tob is not a directory"

test -z "$method" && bail "no method specified for $ob"

test -n "$DEBUG" && {
    echo DEBUG: nominal object=$ob
    echo DEBUG: thinobject=$tob
    echo DEBUG: method=$method
    echo DEBUG: args1=\'$args\' args2=\'$*\'
    }

## SPECIAL CASES: tob and isa methods precede the normal method search
test "$method" == "tob" && {
    test -z "$*" && echo $tob
    for arg in $*; do
        echo $tob/$arg
    done
    exit 0
    }

test "$method" == "isa" && {
    test -e $tob/^ && {
        class=$tob/^
        test -L $class || bail "$ob ^ property is not a symlink..."
        pad=""
        while [ -L $class ]; do
            classlink=$(readlink -f $class)
            if [ $VERBOSE ]; then # show full path of class link, no indent
                echo $classlink
            else                  # show class name, indented
                classname $classlink
                echo "$pad$classname"
            fi
            class=$class/^
            pad="  "$pad
        done
        exit 0
        }
    ## ASSERT: no object class specified, so the default is:
    echo thinobject
    exit 0
    }

## ASSERT a method was passed

test -e $tob/^ && { # object ^ file/directory/link exists...

    ## not sure the following test is really required or valid...
    ##    e.g., one could have a once-only object I suppose ...
    ## require object's ^ to be a symlink:
    test ! -L $tob/^ &&
        bail "ERROR: object $ob ^ property is not a symlink"

    test -z $NOT_STRICT && { # safety check
        check_class $(readlink -f $tob/^) ||
            bail "invalid class/method handler location"
        }

    isa=$tob/^
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
        isa=$isa/^ # continue search with parent class, if any...
    done

    }

## ASSERT: no ^ file, so handle as base class thinobject

## default methods follow

test -n "$SHOWHEADER" && echo $ob: 

test "$method" == "exists" && {
    test $VERBOSE && echo object $ob exists
    exit 0
    }

test "$method" == "ls" && {
    if [ -z $NOCD ]; then
        cd $tob
        target="$@"
    else
        target="$tob/$@"
    fi
  # test $DEBUG -a $VERBOSE && echo exec ls -p $args $target
    exec ls -p $args $target
    }

test "$method" == "wc" && {
    if [ -z $NOCD ]; then
        cd $tob
        target="$*"
    else
        target="$tob/$*"
    fi
  # test $DEBUG -a $VERBOSE && echo exec wc -p $args $target
    exec wc $args $target
    }

test "$method" == "find" && {
    test -z "$NOCD" && {
        cd $tob
        if [ -n "$*" ]; then
          # exec find -L $* # follow symlinks by default!
            test $DEBUG -a $VERBOSE &&
                echo exec find -follow -not -regex '.*/\..*' $*
            exec find -follow -not -regex '.*/\..*' $* 2>/dev/null # follow symlinks by default!
        else # by default, show output without leading "./"
          # exec find -L -printf "%P\n"
            test "$DEBUG" -a "$VERBOSE" &&
                echo exec find -not -type d -not -regex '.*/\..*' -follow -printf "%P\n"
            exec find -not -type d -not -regex '.*/\..*' -follow -printf "%P\n" 2>/dev/null
        fi
        }
    test $DEBUG -a $VERBOSE && echo exec find $tob $*
    exec find $tob $* 2>/dev/null
    }

test "$method" == "cat" && {
    if [ -z $NOCD ]; then
        cd $tob
        target="$*"
    else
        target="$tob/$*"
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
    test ! -e $tob/$prop && bail "ERROR: no property $prop"
    if [ -n "$1" ]; then
        exec echo "$*" > $tob/$prop
    else
        exec cat > $tob/$prop
    fi
    }

test "$method" == "param" && {
    tag="$1"
    shift
    value="$1"
    shift
    cd $tob
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

test "$method" == "method" && {
    tag="$1"
    shift
    value="$1"
    shift
    cd $tob
    test -z "$tag" && { # list all methods
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
    if [ -z "$1" ]; then target="%"; else target="$*"; fi
    if [ -z $NOCD ]; then
        cd $tob
    else
        for f in $*; do
            ## non-option argument is the file to edit:
            if [ $f == ${f#-} ]; then
                target="$target $tob/$f"
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
        for f in $tob/*; do
            rm $f
        done
        rmdir $tob 
        rm $ob
    else
        for f in $*; do
            property=$tob/$f
            test "$VERBSOSE" && echo delete property $property
            if [ -f $property ]; then   # ordinary file
                rm $property
            elif [ -L $property ]; then # symlink
                rm $property
            elif [ -d $property ]; then # directory
                rmdir $property || bail "$property directory not empty"
            else                        # directory
                echo \"$property\" not found or at least not deleted...
            fi
        done
    fi
    exit 0
    }

test $VERBOSE && echo no method $method found 
bail "no method $method found"
