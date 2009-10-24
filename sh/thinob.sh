#!/bin/bash

TOB_DEFAULT_CLASS_FOR_FILE=/usr/local/lib/thinob/Filesystem/File
TOB_DEFAULT_CLASS_FOR_DIRECTORY=/usr/local/lib/thinob/Filesystem/Directory

# require class handlers & methods to be under one of these paths:
LIB=( ~/lib /usr/local/lib /home/.usr-local/lib /usr/lib )
ROOT=( thinob tob ThinObject )

# combine these into an ordered set of allowed root paths:
declare -a LIBROOTS
i=0
for lib in ${LIB[@]}; do
    for root in ${ROOT[@]}; do
        LIBROOTS[$i]=$lib/$root
        i=$(($i + 1))
    done
done

####################
## define fuctions and related variables:
####################

function manpage() { # print manpage at end of this script...
    exec /usr/bin/awk '/^NAME$/{ok=1}ok' $0
    }

function bail () {
    test -z "$QUIET" && echo $* >&2
    exit 1
    }

function TOB_error () {
    unset EXIT_VALUE
    while [ "${1:0:1}" == "-" ]; do # handle option ...
        opt=$1 && shift
      # RESTORE_VERBOSE="$VERBOSE" # in case this is changed
        case $opt in
        --exit|-x) EXIT_VALUE=$1 && shift ;;
        -v) VERBOSE=1 ;;
        -V) unset VERBOSE ;;
        *)  echo "TOB_error(): unknown option: \"$opt\"" 1>&2
            echo "    SYNOPSIS: TOB_error [--exit|-x N] [-v|V] args ..." 1>&2
            ;;
        esac
    done
    echo -e $TOB_object.$TOB_method: $* 1>&2
    test "$VERBOSE" && { PAD="    "
        echo "${PAD}TOB_object: $TOB_object" 1>&2
        echo "${PAD}TOB_method: $TOB_method" 1>&2
        echo "${PAD}TOB_object_path: $TOB_object_path" 1>&2
        echo "${PAD}method path: $0" 1>&2
        echo "${PAD}pwd: $(pwd)" 1>&2
        }
    test "$EXIT_VALUE" && exit $EXIT_VALUE
  # VERBOSE="$RESTORE_VERBOSE"
    }   

function cd_into_object () {
    ob_path=$1
    TOB_path_to_object=$TOB_path_to_object/$ob_path
    cd $ob_path ||
        bail failed to cd to $TOB_path_to_object
    return
    }

function resolve_object () {
    ob=$1

    # cd to directory if it contains a class link:
    test -d $ob && ( test -L "$ob/^" || test -L "$ob/.^" ) &&
        cd_into_object $ob &&
            return

    # if ob is a symlink, resolve it to a real path:
    test -L $ob &&
        ob=$(/bin/readlink -f $ob)

    # cd into any non-object directories, just to be done with them:
    dirs=${ob$/*}
    test $dirs == $ob || {
        cd_into_object $dirs
        ob=${ob##*/}
        }

    # we already know that ob is not a thinobject, so dot it and try again:
    test -d .$ob && ( test -L ".$ob/^" || test -L ".$ob/.^" ) &&
        cd_into_object .$ob &&
            return

    ## ASSERT: neither ob nor dot_ob is an explicit thinobject

    # cd into ob if it's a directory
    test -d $ob && 
        cd_into_object $ob &&
            return

    # or cd into dot_ob if it's a directory
    test -d .$ob && 
        cd_into_object .$ob &&
            return

    # nothing found to resolve object path, so check thinobject classes:
    for path in ${LIBROOTS[@]}; do
        test -e $path/$ob && {
            test $TOB_path_to_object == . ||
                bail failed to resolve object: $TOB_path_to_object/$ob
            TOB_path_to_object=""
            cd_into_object $path/$ob
            return
            }
    done

    # no object path resolved
    return 1
    }

function resolve_class_path () { 

    test -d . && { ## object is a directory
        test -L ./^ && 
            TOB_class_path=./^ &&
                return

        test -L ./.^ && 
            TOB_class_path=./.^ &&
                return

        TOB_class_path=$TOB_DEFAULT_CLASS_FOR_DIRECTORY 
        return
        }

    test -f $TOB_object_path && 
        TOB_class_path=$TOB_DEFAULT_CLASS_FOR_FILE &&
            return

    bail "$TOB_object is not a directory or file..."
    }

function resolve_attribute_search_path () {

    # search starts with the object path, followed by its class path:
    attr_paths=($TOB_object_path $TOB_class_path)

    # declare index to last and next entries in path array
    local last=1
    local next=2

    while test -d ${attr_paths[$last]}/; do

        if test -L ${attr_paths[$last]}/^; then
            attr_paths[$next]=${attr_paths[$last]}/^
        elif test -L ${attr_paths[$last]}/.^; then
            attr_paths[$next]=${attr_paths[$last]}/.^
        else
            break
        fi

        last=$next
        next=$(($next + 1))
    done
    }

function check_and_parse_class () { # true if class begins with allowed root
    local class=$(/bin/readlink -f $1)
    for path in ${LIBROOTS[@]}; do
        test ${class#$path/} == $class || {
            classname=${class#$path/}  # note this side effect!!
            return
            }
    done
    return 1
    }

function resolve_method_search_path () {

    # method search starts with object class, 2nd entry in attr_paths array:
    attr_index=1

    # check that attr_paths array has been initialized:
    test -n "${attr_paths[$attr_index]}" ||
        bail "call resolve_attribute_search_path() before resolve_method_search_path()"

    index=0
    while test -n "${attr_paths[$attr_index]}"; do
        
        check_and_parse_class ${attr_paths[$attr_index]} && {
            search_paths[$index]=${attr_paths[$attr_index]}
            class_names[$index]=$classname
            index=$(($index + 1))
            attr_index=$(($attr_index + 1))
            continue
            }
        ## ASSERT: the class did not start with one of LIBROOTS list

        test $index == 0 || 
            bail non-method class cannot follow method class in search path

        attr_index=$(($attr_index + 1))
    done
    }

resolve_method_path () {
    local method=$1 && shift
    local super=0
    while test "${method:0:7}" == "SUPER::"; do
        method=${method:7}
        super=$(($super+1))
    done
    for searchpath in ${search_paths[@]}; do
        test -x $searchpath/$method && {
            test $super == 0 && {
                TOB_method_path=$searchpath/$method
                return
                }
            super=$(($super - 1))
            }
    done
    return 1
    }

## this function is for export, and iterates on the :-delimited search list:
TOB_resolve_method_path () {
    local method=$1 && shift
    local super=0
    while test "${method:0:7}" == "SUPER::"; do
        method=${method:7}
        super=$(($super+1))
    done
    for searchpath in ${TOB_method_search_paths//:/ }; do
        test -x $searchpath/$method && {
            test $super == 0 && {
                TOB_method_path=$searchpath/$method
                return
                }
            super=$(($super - 1))
            }
    done
    return 1
    }

####################
## export thinobject utility functions
####################
export -f TOB_error
export -f TOB_resolve_method_path


####################
## process argument list for any options:
####################

ob=$1 && shift
unset method
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

test $method && {
    ####################
    ## special case: dispatch method from -m or --method option on objects:
    ####################
    while [ $ob ]; do
        if [ ${ob/=} != $ob ]; then # tag=value form detected
            args="$args $ob"
        else
            test $VERBOSE &&
                echo tob $opt $ob.$method $args
            tob $opt $ob.$method $args ||
                bail "failed in $ob.$method"
        fi
        ob=$1 && shift
    done
    exit 0
    }

## initialize path from caller to object starting from current directory:
TOB_path_to_object=.

####################
## check for & resolve colon-delimited (contained) objects to the final object:
####################

## replace any '::' sequences temporarily:
ob=${ob//::/__2COLONS__}
while [ ${ob/:/} != $ob ]; do
    oball=$ob
    ob=${ob%%:*}
    oblist=${oball#*:}

    resolve_object $ob ||
        bail no object resolved from $TOB_path_to_object/$ob

    ob=$oblist

    done

ob=${ob//__2COLONS__/::}

####################
## object still includes method, so parse method from object.method
####################

TOB_method=${ob##*.}
TOB_object=${ob%.*}

test $TOB_method == $ob && 
    bail no method parsed from target $ob

test -n "$DEBUG" && {
    echo DEBUG: TOB_object=$TOB_object
    echo DEBUG: TOB_method=$TOB_method
    }

test -n "$TOB_object" ||
    bail "no object parsed with method $TOB_method"

test -n "$TOB_method" ||
    bail "no method parsed, object $TOB_object"

####################
## ASSERT: ob and method have been parsed, but not checked
####################

resolve_object $TOB_object &&
    resolve_class_path

test -n $TOB_class_path || {  ## check if object is a file:
    test -f $TOB_object && 
        TOB_class_path=$TOB_DEFAULT_CLASS_FOR_FILE
    }

test -n $TOB_class_path || 
    bail no object path resolved from $TOB_object

test -n "$DEBUG" && {
    echo DEBUG: TOB_path_to_object=$TOB_path_to_object
    echo DEBUG: TOB_class_path=$TOB_class_path
    }

test -n "$DEBUG" &&
    echo DEBUG: args1=\'$args\' args2=\'$*\'
    

####################
## now need to create TOB_PATH and TOB_ATTR_PATH
####################

declare -a attr_paths
resolve_attribute_search_path ||
    bail failure in resolve_attribute_search_path function

# echo RESULTS:
# printf "\t%s\n" "${attr_paths[*]}"

declare -a search_paths
declare -a class_names
resolve_method_search_path ||
    bail failure in resolve_method_search_path function

# printf "\t%s\n" "${search_paths[*]}"
# printf "\t%s\n" "${class_names[*]}"

####################
## export thinobject variables
####################
export TOB_object
export TOB_method
export TOB_object_path
export TOB_class_path


save_IFS="$IFS"
IFS=:
export TOB_attribute_search_paths="${attr_paths[*]}"
export TOB_method_search_paths="${search_paths[*]}"
export TOB_type="${class_names[*]}"
IFS="$save_IFS"

test -n "$DEBUG" && {
    echo DEBUG: TOB_attribute_search_paths=$TOB_attribute_search_paths
    echo DEBUG: TOB_method_search_paths=$TOB_method_search_paths
    echo DEBUG: TOB_type=$TOB_type
    }

resolve_method_path $TOB_method &&
    exec $TOB_method_path $TOB_object $args "$@"

####################
## no executable method was resolved, so try some built-ins:
####################

test $TOB_method == path && {
    test -z "$*" && echo $TOB_object_path
    for arg in $*; do
        echo $TOB_object_path/$arg
    done
    exit 0
    }

test "$TOB_method" == "type" && {
    echo $TOB_type
    exit 0
    }

test "$TOB_method" == "isa" && {
    pad=""
    for class in ${class_names[*]}; do
        echo "$pad$class"
        pad="  $pad"
    done
    exit 0
    }

## I think this SHOWHEADER thing was a workaround for aggregate objects...
test -n "$SHOWHEADER" &&
    echo $TOB_object: 

####################
## no ob.method found, so check for properties @method or %method
####################

unset property default_handler
for path in ${attr_paths[@]}; do
    test -e $path/\@$TOB_method && { # found @method
        property=$path/@$TOB_method
        default_handler=_default-list
        break
        }
    test -e $path/.\@$TOB_method && { # found @method
        property=$path/.@$TOB_method
        default_handler=_default-list
        break
        }
    test -e $path/\%$TOB_method && { # found %method
        property=$path/%$TOB_method
        default_handler=_default-dict
        break
        }
    test -e $path/.\%$TOB_method && { # found %method
        property=$path/.%$TOB_method
        default_handler=_default-dict
        break
        }
    test -e $path/\%\@$TOB_method && { # found %@method
        property=$path/%@$TOB_method
        default_handler=_default-dict-list
        break
        }
    test -e $path/.\%\@$TOB_method && { # found %@method
        property=$path/.%@$TOB_method
        default_handler=_default-dict-list
        break
        }
done

test -n "$property" && {
    # search for _default-list or _default-dict method:
    for path in ${search_paths[@]}; do
        test -e $path/$default_handler && {
          # echo TODO: /bin/echo exec $path/$default_handler $property $@
            exec $path/$default_handler $TOB_object $property $@ # found & dispatched
            }
    done

    ## ASSERT: property was found, but no default handler, so handle inline:

    test $default_handler == _default-list && { # called ob.foo, found @foo...
        lines="$1"
        test -z "$lines" &&
            exec /bin/cat $property
        exec /usr/bin/perl -e "\$[=1; @r=<>; print @r[$lines]" $property
        # leaving unreachable stub as documentation...
        exec STUB echo $property list accessor lines $lines
        }
    
    test $default_handler == _default-dict && { # called ob.foo, found %foo...
        keys="$@"
        test -z "$keys" &&
            exec /bin/cat $property
        keys=${keys// /|}
        exec /usr/bin/awk -v IGNORECASE=1 "\$1~/$keys/" $property
        exec STUB echo $property dict accessor with keys $keys ${keys// /|}
        }

    test $default_handler == _default-dict-list && { # ... found %@foo...
        keys="$@"
        test -z "$keys" &&
            exec /bin/cat $property
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

for path in ${search_paths[@]}; do
    ## ASSERT: class exists
    test -e $path/_default && {
        test -x $path/_default && {
          # echo DEBUG thinob: exec $path/_default $TOB_object $TOB_method $*
            exec $path/_default $TOB_object $TOB_method $*
            }
        ## ASSERT: _default is not executable
        ## maybe it can contain a recipe to be executed?
        bail 'non-executable _default "method" found'
        }
done

bail "no method $TOB_method found"

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
    path
    output the object directory path

    type
    output the class hierarchy

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
    TOB_object -- the object name as passed to the thinob enabler

    TOB_class -- the nominal class name

    TOB_class_path -- the class directory or handler path

    TOB_object_path -- the fully resolved object name

    TOB_method -- the invoked method

    TOB_PATH -- search path for object through class hierarchy

EXPORTED FUNCTIONS
    TOB_error -- print message on STDERR
        SYNOPSIS: TOB_error [--exit|-x NUMBER] [-v|V] message ..."
        OPTIONS:
            --exit N  -- specify exit status number
            -x N      -- specify exit status number
            -v        -- be verbose; show thinobject state variables
            -V        -- don't be verbose
        output format is: $TOB_object.$TOB_method: ARGUMENTS...

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
