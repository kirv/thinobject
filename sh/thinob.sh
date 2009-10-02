#!/bin/sh

# define a special exit status to search up object classes, sub to super(s):
TOB_CONTINUE_SEARCH=100

# require class handlers & methods to be under this path, unless --not-strict
LIB=( ~/lib /usr/local/lib /home/.usr-local/lib /usr/lib )
ROOT=( thinob tob ThinObject )

function manpage() { # print manpage at end of this script...
    exec /usr/bin/awk '/^NAME$/{ok=1}ok' $0
    }

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

function classname () { # remove class library root from class link
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

function class_as_object () {
    local class="$1"
    for lib in ${LIB[@]}; do
        for root in ${ROOT[@]}; do
            classpath=$lib/$root/$class
            test -d $classpath && { # got it!
                return 0
                }
        done
    done
    return 1
    }

function bail () {
    test -z "$QUIET" && echo $* >&2
    exit 1
    }

function bail_rtnval () {
    rtnval="$1" && shift
    test -z "$QUIET" && echo $* >&2
    exit $rtnval
    }

function tob_error () {
    unset EXIT_VALUE
    while [ "${1:0:1}" == "-" ]; do # handle option ...
        opt=$1 && shift
      # RESTORE_VERBOSE="$VERBOSE" # in case this is changed
        case $opt in
        --exit|-x) EXIT_VALUE=$1 && shift ;;
        -v) VERBOSE=1 ;;
        -V) unset VERBOSE ;;
        *)  echo "tob_error(): unknown option: \"$opt\"" 1>&2
            echo "    SYNOPSIS: tob_error [--exit|-x N] [-v|V] args ..." 1>&2
            ;;
        esac
    done
    echo -e $tob_object.$tob_method: $* 1>&2
    test "$VERBOSE" && { PAD="    "
        echo "${PAD}tob_object: $tob_object" 1>&2
        echo "${PAD}tob_method: $tob_method" 1>&2
        echo "${PAD}tob_path: $tob_path" 1>&2
        echo "${PAD}method path: $0" 1>&2
        echo "${PAD}pwd: $(pwd)" 1>&2
        }
    test "$EXIT_VALUE" && exit $EXIT_VALUE
  # VERBOSE="$RESTORE_VERBOSE"
    }   
export -f tob_error

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

    elif [ "$ob" == "-H" -o "$ob" == "--not-hidden" ]; then
        ## with new or clone methods, create object directly, not dotted...
        NOT_HIDDEN=1
        opt="$opt --not-hidden"

    elif [ "$ob" == "-T" -o "$ob" == "--no-touch" ]; then
        ## with new or clone methods, create hidden ob, don't 'touch' nominal
        NO_TOUCH=1
        opt="$opt --no-touch"

    elif [ "$ob" == "-q" -o "$ob" == "--quiet" ]; then
        QUIET=1
        opt="$opt --quiet"

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
export tob_object=${ob%.*}
# export tob_method=${ob##*.}


function resolve_object_path () { # return object path in global var tob:
  # tob="${1}__"
    ob=$1
    test -L $ob && ob=$(/bin/readlink -f $ob) # resolve symlinked/aliased ob

    ## ASSERT: $ob is NOT a symlink, so is either a file, directory, or null

    test -d "$ob" && {
        test -L "$ob/^" || test -L "$ob/.^" && {
            ## $ob is a thinobject (but not checked)
            tob=$ob
            return
            }
        }
    
    ## ASSERT: $ob itself is not a thinobject, so check the dot-object...

    if [ "${ob/\/*/}" == "$ob" ]; then # no slash in ob
        tob=.$ob
    else # ob has a slash in it
        tob=${ob%\/*}/.${ob/*\//}
    fi

    test -L "$ob/^" || test -L "$ob/.^" &&
        return # tob is a thinobject
    
    ## object $ob not found, so check if instead it's a ThinObject class:
    class_as_object $ob && { # yes, it is a class
        tob=$classpath       # access the class (almost) as if it's an object
        return
        }

    bail_rtnval 2 "$1 ($ob) is not a thinobject or was not found"
    }

####################
## check for & resolve colon-delimited (contained) objects to the final object:
####################

# test ${ob/::} == $ob || bail double colons not supported... need to fix?

## replace any '::' sequences temporarily:
ob=${ob//::/__2COLONS__}
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

    resolve_object_path $ob

    ob=$tob/$oblist

    # ## encode double colon in ob
    # ob=${ob//::/__2COLONS__}
  # echo _TEST: $ob

    done

ob=${ob//__2COLONS__/::}

# echo _DONE: $ob

####################
## now parse method from object
####################

method=${ob##*.}
ob=${ob%.*}

export tob_ob=$ob
export tob_method=$method

test -n "$DEBUG" && {
    echo DEBUG: object=$ob
    echo DEBUG: method=$method
    }

# echo .
# echo OBJECT: $ob
# echo METHOD: $method

test -z $ob && bail "no object parsed, method $method"

test -z $method && bail "no method parsed, object $ob"

####################
## ASSERT: ob and method have been parsed, but not checked
####################

resolve_object_path $ob
# echo ___TOB: $tob

export tob_tob=$tob
export tob_path=$tob

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
            classlink=$(/bin/readlink -f $class)
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


####################
## ASSERT a method was passed
####################

test -e $tob/^ && { # object ^ file/directory/link exists...

    ## not sure the following test is really required or valid...
    ##    e.g., one could have a once-only object I suppose ...
    ## require object's ^ to be a symlink:
    test ! -L $tob/^ &&
        bail "ERROR: object $ob ^ property is not a symlink"

    test -z $NOT_STRICT && { # safety check
        check_class $(/bin/readlink -f $tob/^) ||
            bail "invalid class/method handler location"
        }

    classname $(/bin/readlink -f $tob/^)
    export tob_class=$classname

    ## remove & count SUPER:: prefixes
    super=0
    while [ ${method:0:7} == "SUPER::" ]; do
        method=${method:7}
        super=$((super+1))
      # echo $super $method
    done
    
    ## search in class, parent class, parent of parent class, etc., 
    isa=$tob/^
    while [ -e $isa ]; do
        ## ASSERT: parent class exists
        if [ -d $isa ]; then # parent class methods directory
          # echo checking for $isa/$method...
            test -e $isa/$method && { # method found!
                
                if [ ! -x $isa/$method ]; then
                    ## suspect this may also happen due to permissions...
                    ## ... so may need to rethink this simple bail-out
                    bail "ERROR: super object method $method not executable"
                fi

                ## ASSERT: method is executable

              # if [ -x $isa/$method ]; then
              #     # call object method handler, grab exitcode
              #     $isa/$method $ob $args "$@"
              #     exitcode=$?
              # fi

                if [ $super == 0 ]; then
                    # call object method handler, grab exitcode
                    $isa/$method $ob $args "$@"
                    exitcode=$?
                else
                    super=$((super-1))
                  # echo skipping method to reach super method
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
            test $exitcode == $TOB_CONTINUE_SEARCH || exit $exitcode
            }
        ## ASSERT: method either not found or handler says to keep going...
        isa=$isa/^ # continue search with parent class, if any...
    done

    }

## ASSERT: no ^ file, so handle as base class thinobject

####################
## default methods follow
####################

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
  # test $DEBUG -a $VERBOSE && echo exec /bin/ls -p $args $target
    exec /bin/ls -p $args $target
    }

test "$method" == "wc" && {
    if [ -z $NOCD ]; then
        cd $tob
        target="$*"
    else
        target="$tob/$*"
    fi
  # test $DEBUG -a $VERBOSE && echo exec /bin/wc -p $args $target
    exec /usr/bin/wc $args $target
    }

test "$method" == "find" && {
    test -z "$NOCD" && {
        cd $tob
        if [ -n "$*" ]; then
            test "$DEBUG" -a "$VERBOSE" &&
                echo exec /usr/bin/find $*
            exec /usr/bin/find $*
        else # by default, show output without leading "./"
            test "$DEBUG" -a "$VERBOSE" &&
                echo exec /usr/bin/find -not -type d -printf "%P\n"
            exec /usr/bin/find -not -type d -printf "%P\n"
        fi
        }
    test "$DEBUG" -a "$VERBOSE" && echo exec /usr/bin/find $tob $*
    exec /usr/bin/find $tob $*
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
            /bin/cat $prop
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
        exec /bin/echo "$*" > $tob/$prop
    else
        exec /bin/cat > $tob/$prop
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
        test -e $tag\=* && /bin/rm $tag\=* 
        /usr/bin/touch $tag\=$value
        }
    ## ASSERT: $tag is defined -- but may or may not exist
    test ! -e $tag\=* && exit 1
    exec /bin/ls $tag\=*
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
        test -e $tag\=* && /bin/rm $tag\=* 
        /usr/bin/touch $tag\=$value
        }
    ## ASSERT: $tag is defined -- but may or may not exist
    test ! -e $tag\=* && exit 1
    exec /bin/ls $tag\=*
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

test "$method" == "touch" && {
    if [ -z "$1" ]; then target="%"; else target="$*"; fi
    if [ -z $NOCD ]; then
        cd $tob
    else
        for f in $*; do
            ## non-option argument is the file to touch:
            if [ $f == ${f#-} ]; then
                target="$target $tob/$f"
            else
                target="$target $f"
            fi
        done
    fi
    test $VERBOSE && echo touch $target
    /usr/bin/touch $target
    exit 0
    }

test "$method" == "grep" && {
    opts=''
    pat=$1
    shift
    while [ $pat != ${pat#-} ]; do # collect any grep options
        opts="$opts $pat"
        pat=$1
        shift
    done
    if [ -z $NOCD ]; then
        cd $tob
        target=$@
    else
        for f in $*; do
            if [ $f == ${f#-} ]; then
                target="$target $tob/$f"
            else
                opts="$opts $f"
            fi
        done
    fi
    test $VERBOSE && echo grep $opts $pat $target
    grep $opts $pat $target
    exit 0
    }

test "$method" == "mkdir" && {
    if [ -z "$1" ]; then target="%"; else target="$*"; fi
    if [ -z $NOCD ]; then
        cd $tob
    else
        for f in $*; do
            ## non-option argument is the file/dir name to mkdir:
            if [ $f == ${f#-} ]; then
                target="$target $tob/$f"
            else
                target="$target $f"
            fi
        done
    fi
    test $VERBOSE && echo mkdir $target
    /bin/mkdir $target
    exit 0
    }

test "$method" == "delete" && { ## CAUTION!! object & content will be removed
    ## if no arguments, delete the thinobject completely with rm -r:
    test -z "$*" && { 

        ## delete symlink to object, not the object!
        test -L $tob_object && { 
            test "$VERBOSE" && echo deleting symlink: $tob_object
            /bin/rm $tob_object ||
                tob_error -v -x $? failed to delete $tob_object
            exit
            }

        ## the object and all content will be deleted
        ## ... but first make sure it's a directory:
        test -d $tob_path || {
            tob_error -v -x 1 error??: $tob_path is not a directory
            }

        ## ... and that it has a class symlink ^ 
        test -L $tob_path/^ ||
            tob_error -v -x 1 error?: $tob_object class symlink not found

        ## ... then go ahead and delete it:
        /bin/rm -r $tob_path ||
            tob_error -v -x $? failed to delete $tob_path directory

        test "$VERBOSE" && echo object directory $tob_path was deleted

        ## exit if there's nothing left:
        test -e $tob_object || exit 0  ## success!

        ## ASSERT: the nominal (former) object remains if it was shadowed

        ## for now just print a warning, consider providing option to delete it
        tob_error "nominal object $tob_object (no longer a thinobject) remains"

        exit 0
        }

    ## ASSERT: arguments are given, representing object properties to delete
    for f in $*; do

        property=$tob/$f

        test -e $property || { # no such property
            test "$VERBOSE" && echo no property: $property
            tob_error no property: $property
            continue
            }

        ## ASSERT: property exists, should be a symlink, file, or directory

        test -L $property && { # symlink
            test "$VERBOSE" && echo deleting symlink property $property
            /bin/rm $property ||
                tob_error -x $? failed to delete symlink $property
            continue
            }

        test -f $property && { # file
            test "$VERBOSE" && echo deleting file property $property
            /bin/rm $property ||
                tob_error -x $? failed to delete file $property
            continue
            }

        test -d $property && { # directory
            test "$VERBOSE" && echo deleting directory property $property
            /bin/rm -r $property ||
                tob_error -x $? failed to delete directory $property
            continue
            }

        ## can't happen, but handle it if it does...
        tob_error -x 1 -v failed to delete property $property

    done

    exit 0
    }

####################
## no ob.method found, so check for properties @method or %method
####################

isa=$tob # 
unset property default_handler
while [ -e $isa ]; do 
    test -e $isa/\@$method && { # found @method
        property=$isa/@$method
        default_handler=_default-list
        break
        }
    test -e $isa/\%$method && { # found %method
        property=$isa/%$method
        default_handler=_default-dict
        break
        }
    test -e $isa/\%\@$method && { # found %@method
        property=$isa/%@$method
        default_handler=_default-dict-list
        break
        }
    isa=$isa/^ # continue search with parent class...
done

test -n "$property" && {
  # echo FOUND $property, looking for $default_handler...
    isa=$tob/^ # start search for default handler in the object class...
    while [ -e $isa ]; do # search for _default-list or _default-dict
        test -e $isa/$default_handler && {
          # echo TODO: /bin/echo exec $isa/$default_handler $property $@
            exec $isa/$default_handler $ob $property $@ # found & dispatched
            }
        isa=$isa/^ # continue to parent class...
    done

    ## ASSERT: property was found, but no default handler, so handle inline:
  # echo FOUND $property, but no $default_handler...

    test $default_handler == _default-list && { # called ob.foo, found @foo...
        lines="$1"
        test -z $lines && exec /bin/cat $property
        exec /usr/bin/perl -e "\$[=1; @r=<>; print @r[$lines]" $property
        # leaving unreachable stub as documentation...
        exec STUB echo $property list accessor lines $lines
        }
    
    test $default_handler == _default-dict && { # called ob.foo, found %foo...
        keys="$@"
        test -z "$keys" && exec /bin/cat $property
        keys=${keys// /|}
        exec /usr/bin/awk -v IGNORECASE=1 "\$1~/$keys/" $property
        exec STUB echo $property dict accessor with keys $keys ${keys// /|}
        }

    test $default_handler == _default-dict-list && { # ... found %@foo...
        keys="$@"
        test -z "$keys" && exec /bin/cat $property
        keys=${keys// /|}
        exec /usr/bin/awk -v IGNORECASE=1 -v keys="$keys" '
            NR==1{
                while(++i<=NF){
                    sub($i,"^" i+1 "$",keys)
                    k[i+1] = $i
                    }
                }
            NR ~ keys {print k[NR]" = "$0}' $property
        exec STUB echo $property dict-list accessor with keys $keys ${keys// /|}
        }
    }

####################
## still no method found -- check for _default method...
####################

isa=$tob/^ # start looking in the object class ...
while [ -e $isa ]; do
    ## ASSERT: class exists
    test -e $isa/_default && {
        test -x $isa/_default && {
          # echo DEBUG thinob: exec $isa/_default $ob $method $*
            exec $isa/_default $ob $method $*
            }
        ## ASSERT: _default is not executable
        ## maybe it can contain a recipe to be executed?
        bail 'non-executable _default "method" found'
        }
    isa=$isa/^ # continue search with parent class, if any...
done


test $VERBOSE && echo no method $method found 
bail "no method $method found"

##############
## manpage follows
##############
NAME
    thinob, tob -- ThinObject ``enabler''
SYNOPSIS
    tob [OPTIONS]... object.method [METHOD_OPTIONS]... [ARGUMENTS]...
    tob -m method object...
DESCRIPTION
    The thinob or tob script enables the specified object to execute
    its specified method under the ThinObject scheme.

    ThinObject strives to achieve object oriented programming and data
    management directly on the filesystem, in a language-independent way.
    Methods are executable programs, so may be written in any language.
    The key to the thinobject system is the use of a symlink to a class
    directory (or executable handler), named "^".  Methods and attributes
    are searched for along the chain of class links.
RETURN VALUE
    0   ok, no error
    1   some error occurred
    2   object is not a thinobject
OPTIONS
    -d
    --debug
    turn on debug output

    -v
    --verbose
    turn on verbose output

    -m M
    --method M
    apply method M to the following list of objects    

    -a ARGS...
    --arg ARGS...
    provide arguments; useful in conjunction with the --method option

    -h
    --help
    show this help screen (manpage)

    -S
    --not-strict
    override normal validity checking of class path
    
    --no-cd
    do not chdir into object directory to execute the method

    -q
    --quiet
    suppress output to stderr on errors
    
OBJECT CREATION
    Use thinob-new or tob-new to create objects.

BUILT-IN METHODS
    tob
    output the object directory path

    isa
    output the class hierarchy

    exists
    return success if the object exists

    ls [LS_OPTIONS] [file]...
    run the shell ``ls'' command in the object directory

    wc [WC_OPTIONS] [file]...
    run the shell ``wc'' command in the object directory

    find [FIND_ARGUMENT]...
    run the shell ``find'' command in the object directory

    cat [FILE]...
    run the shell ``cat'' command in the object directory

    method
    output list of methods available to the object

    method METHOD
    output the pathname of METHOD in the object

    edit [EDIT_OPTIONS] FILE...
    invoke the shell ``EDITOR'' in the object directory

    touch [TOUCH_OPTIONS] FILE...
    run the shell ``touch'' command in the object directory

    mkdir [MKDIR_OPTIONS] DIR...
    run the shell ``mkdir'' command in the object directory

    delete [FILE]...
    delete selected file(s) or the entire object

    set FILE
    overwrite the value (contents) of FILE in the object
    NEEDS WORK!!

    param
    output attributes of the object, one per line
    NEEDS WORK!!

    foo [ARG]...
    if no method ``foo'' is found in the class hierarchy, search
    for a LIST property (@foo) or a DICTIONARY property (%foo) and
    treat this pseudo method as an ``accessor'' of that property.

PROPERTIES
    The ThinObject system uses ordinary files and directories in the
    filesystem, so the contents of an object is arbitrary.  It may be
    convenient/helpful to think of the contents of an object as its
    ``properties'', if only to distinguish them from otherwise 
    ordinary files (which they really are).

    However, special meaning is applied to certain files, as follows:

    ^
    symlink to the parent class

    @
    @foo
    list property, a file containing a list of entries, one per line.
    @, the anonymous list property, may be scanned when any object method
    is invoked.

    %
    %foo
    dictionary property, file containing a list of tag=value entries,
    one pair per line.  %, the anonymous dictionary property, may be 
    scanned in automatically during method invocation, so can be used
    to store various object attributes.

    %@
    %@foo
    dictionary property implemented as a list, with keys listed all
    the first line, values on subsequent lines.  Blank lines and 
    comments lines are skipped.

    foo=bar
    attribute 'foo' is assigned the value 'bar'.

EXPORTED VARIABLES
    tob_object -- the object name as passed to the thinob enabler

    tob_method -- the invoked method

    tob_path -- the fully resolved object name

    tob_tob -- the fully resolved object name

    tob_ob -- the nominal object name (may be partially resolved)

EXPORTED FUNCTIONS
    tob_error -- print message on STDERR
        SYNOPSIS: tob_error [--exit|-x NUMBER] [-v|V] message ..."
        OPTIONS:
            --exit N  -- specify exit status number
            -x N      -- specify exit status number
            -v        -- be verbose; show thinobject state variables
            -V        -- don't be verbose
        output format is: $tob_object.$tob_method: ARGUMENTS...

SEE ALSO
    Each thinobject class is *supposed to* provide a help method, and
    a --help option to each of its methods.

BUGS
    Probably plenty.  This is an experimental system, with many details
    remaining to flesh out and/or fix.

    Not sure the --quiet option is working quite right...

AUTHOR
    Ken Irving <fnkci@uaf.edu> (c) 2007
END_OF_MANPAGE
