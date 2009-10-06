#!/bin/bash

test -e /etc/thinobject.conf &&
    source /etc/thinobject.conf

# require class handlers & methods to be under this path, unless --not-strict
LIB=( ~/lib /usr/local/lib /home/.usr-local/lib /usr/lib )
ROOT=( thinob tob ThinObject )

function manpage() { # print manpage at end of this script...
    exec /usr/bin/awk '/^NAME$/{ok=1}ok' $0
    }

DEFAULT_CLASS_FOR_FILE=/usr/local/lib/thinob/Filesystem/File
DEFAULT_CLASS_FOR_DIRECTORY=/usr/local/lib/thinob/Filesystem/Directory

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

declare -a tob_classlinks
export tob_classlinks      # NOTE: bash 3.2 arrays are not exportable!
function follow_class_links () {
    test -n "$tob_classlinks" && # short-circuit if already done!
        return 0
    class=$1
    while [ -d $class ]; do
        classlink=$(/bin/readlink -f $class)
        tob_classlinks=($tob_classlinks $classlink)
        if test -L $class/^; then
             class=$class/^
        elif test -L $class/.^; then
            class=$class/.^
        else
            return 0
        fi
    done
    return 1
    }

declare -a tob_classnames
function parse_class_names () {
    test -n "$tob_classnames" &&
        return 0
    test -n $tob_classlinks ||
        follow_class_links $classpath
    for classlink in ${tob_classlinks[@]}; do
        classname $classlink
        tob_classnames=($tob_classnames $classname)
    done
    return 0
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

tob_resolve_methodpath () {
    local method=$1 && shift
    local super=0
    while test "${method:0:7}" == "SUPER::"; do
        method=${method:7}
        super=$(($super+1))
    done
    local searchpath=$tob_classpath
    while [ -d $searchpath ]; do
        test -x $searchpath/$method && {
            test $super == 0 && {
                tob_methodpath=$searchpath/$method
                return 0
                }
            super=$(($super - 1))
            }
        if test -L $searchpath/^; then
             searchpath=$searchpath/^
        elif test -L $searchpath/.^; then
            searchpath=$searchpath/.^
        else
            return 1
        fi
    done
    }
export -f tob_resolve_methodpath

ob=$1 && shift
while [ -n "$ob" -a ${ob#-} != $ob ]; do # option detected by leading "-" ...

    if [ "$ob" == "-d" -o "$ob" == "--debug" ]; then
        DEBUG=1
        opt="$opt -d"

    elif [ "$ob" == "-v" -o "$ob" == "--verbose" ]; then
        VERBOSE=1
        SHOWHEADER=1
        opt="$opt -v"

    elif [ "$ob" == "-m" -o "$ob" == "--method" ]; then
        method=$1 && shift
        test $method || bail "no method argument"

    elif [ "$ob" == "-a" -o "$ob" == "--arg" ]; then
        args="$args $1" && shift

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
    ob=$1 && shift # try again...
done

test -z "$ob" && bail "no object specified"

test $method && { # iterate method on multiple objects (see -m, --method)
    while [ $ob ]; do
        if [ ${ob/=} != $ob ]; then # tag=value form detected
            args="$args $ob"
        else
            test $VERBOSE && echo tob $opt $ob.$method $args
            tob $opt $ob.$method $args || bail "failed in $ob.$method"
        fi
        ob=$1 && shift
    done
    exit 0
    }

# ASSERT: $ob contains object(s) and method
# echo START: $ob
export tob_object=${ob%.*}
# export tob_method=${ob##*.}


function resolve_object_class_paths () { # set tob and classpath variables
    ob=$1
    unset tob
    unset classpath

    test -L $ob && ob=$(/bin/readlink -f $ob) # resolve symlinked/aliased ob

    ## ASSERT: $ob is NOT a symlink, so is either a file, directory, or null

    test -d "$ob" && { ## ob is a directory
        if test -L "$ob/^"; then
            classpath=$ob/^
        elif test -L "$ob/.^"; then
            classpath=$ob/.^
        fi
        test -n "$classpath" &&
            tob=$ob &&
                return
        }
    
    ## ASSERT: $ob itself is not a thinobject, so check the dot-object...

    if test "${ob/\/*/}" == "$ob"; then # no slash in ob
        dot_ob=.$ob
    else # ob has a slash in it
        dot_ob=${ob%\/*}/.${ob/*\//}
    fi
    test -L $dot_ob && dot_ob=$(/bin/readlink -f $dot_ob) # resolve symlinked/aliased ob

    test -d "$dot_ob" && { ## dot_ob is a directory
        if test -L "$dot_ob/^"; then
            classpath=$dot_ob/^
        elif test -L "$dot_ob/.^"; then
            classpath=$dot_ob/.^
        fi
        test -n "$classpath" &&
            tob=$dot_ob &&
                return
        }

    ## object $ob not found, so check if instead it's a ThinObject class:
    class_as_object $ob && { # yes, it is a class
        tob=$classpath       # access the class (almost) as if it's an object
        return
        }

    ## $ob is neither an object nor a class, try an implicit class link:
    if test -d $ob; then
      # echo $ob is a directory
        tob=$ob
        classpath=$DEFAULT_CLASS_FOR_DIRECTORY
    elif test -f $ob; then
      # echo $ob is a file
        tob=$ob
        classpath=$DEFAULT_CLASS_FOR_FILE
    elif test -d $dot_ob; then
      # echo $dot_ob is a directory
        tob=$dot_ob
        classpath=$DEFAULT_CLASS_FOR_DIRECTORY
    elif test -f $dot_ob; then
      # echo $dot_ob is a file
        tob=$dot_ob
        classpath=$DEFAULT_CLASS_FOR_FILE
    fi
    test -n "$classpath" &&
        return

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

    resolve_object_class_paths $ob

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
export tob_object=$ob
export tob_method=$method

test -n "$DEBUG" && {
    echo DEBUG: object=$ob
    echo DEBUG: method=$method
    }

test -z "$ob" &&
    bail "no object parsed, method $method"

test -z "$method" &&
    bail "no method parsed, object $ob"

####################
## ASSERT: ob and method have been parsed, but not checked
####################

resolve_object_class_paths $ob

test -n "$DEBUG" && {
    echo DEBUG: object path=$tob
    echo DEBUG: class path=$classpath
    }

export tob_tob=$tob
export tob_path=$tob
export tob_classpath=$classpath

###########################################################333

## ASSERT: $ob is a nominal object, $tob is the actual thinobject

test -z "$ob" -o -z "$tob" &&
    bail "no object was parsed"

# test ! -d $tob &&
#     bail "ERROR: $tob is not a directory"

test -z "$method" &&
    bail "no method specified for $ob"

test -n "$DEBUG" && {
    echo DEBUG: nominal object=$ob
    echo DEBUG: thinobject=$tob
    echo DEBUG: method=$method
    echo DEBUG: args1=\'$args\' args2=\'$*\'
    }

## ASSERT a method was passed
####################

tob_resolve_methodpath $method &&
    exec $tob_methodpath $ob $args "$@"

test "$method" == "tob" -o "$method" == "path" && {
    test -z "$*" && echo $tob
    for arg in $*; do
        echo $tob/$arg
    done
    exit 0
    }

test "$method" == "type" && {
  # echo running method: type for $ob $tob $classpath
    follow_class_links $classpath
    test -n "$VERBOSE" && {
        echo ${tob_classlinks[@]}
        exit 0
        }
    parse_class_names
    echo ${tob_classnames[@]}
    exit 0
    }

test "$method" == "isa" && {
    follow_class_links $classpath
    test -n "$VERBOSE" && {
        for classlink in ${tob_classlinks[@]}; do
            echo $classlink
        done
        exit 0
        }
    parse_class_names
    pad=""
    for classname in ${tob_classnames[@]}; do
        echo "$pad$classname"
        pad="  $pad"
    done
    exit 0
    }

test -n "$SHOWHEADER" && echo $ob: 

####################
## no ob.method found, so check for properties @method or %method
####################

unset property default_handler
for isa in $tob $tob_classlinks; do
    test -e $isa/\@$method && { # found @method
        property=$isa/@$method
        default_handler=_default-list
        break
        }
    test -e $isa/.\@$method && { # found @method
        property=$isa/.@$method
        default_handler=_default-list
        break
        }
    test -e $isa/\%$method && { # found %method
        property=$isa/%$method
        default_handler=_default-dict
        break
        }
    test -e $isa/.\%$method && { # found %method
        property=$isa/.%$method
        default_handler=_default-dict
        break
        }
    test -e $isa/\%\@$method && { # found %@method
        property=$isa/%@$method
        default_handler=_default-dict-list
        break
        }
    test -e $isa/.\%\@$method && { # found %@method
        property=$isa/.%@$method
        default_handler=_default-dict-list
        break
        }
done

test -n "$property" && {
  # echo FOUND $property, looking for $default_handler...
    for isa in $tob_classlinks; do # search for _default-list or _default-dict
        test -e $isa/$default_handler && {
          # echo TODO: /bin/echo exec $isa/$default_handler $property $@
            exec $isa/$default_handler $ob $property $@ # found & dispatched
            }
    done

    ## ASSERT: property was found, but no default handler, so handle inline:

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

for isa in $tob_classlinks; do
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
