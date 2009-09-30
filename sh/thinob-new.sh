#!/bin/sh

# require class handlers & methods to be under this path
LIB=( ~/lib /usr/local/lib /home/.usr-local/lib /usr/lib )
ROOT=( thinob tob ThinObject )

function manpage() { # print manpage at end of this script...
    exec /usr/bin/awk '/^NAME$/{ok=1}ok' $0
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

function check_init_method () {
    local class="$1"
    ## ok if no method is specified
    test -z "$TOB_NEW_INIT_METHOD" && return 0
    ## ok if the empty method ("") is specified
    test "$TOB_NEW_INIT_METHOD" == "" && return 0
    ## ASSERT: an init method was specified...
    for lib in ${LIB[@]}; do
        for root in ${ROOT[@]}; do
            classpath=$lib/$root/$class
            test -d $classpath && { # got it!
                test -x $classpath/$TOB_NEW_INIT_METHOD && return 0
                bail method $TOB_NEW_INIT_METHOD not found in class $class
                }
        done
    done
    return 1
    }

function bail () {
    echo $* >&2
    exit 1
    }

function resolve_ob_to_tob () { # return object path in global var tob:
  # tob="${1}__"
    ob=$1
    test -L $ob && ob=$(/bin/readlink -f $ob) # resolve symlinked/aliased ob

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
    
    ## object $ob not found, so check if instead it's a ThinObject class:
    class_as_object $ob && { # yes, it is a class
        tob=$classpath       # access the class (almost) as if it's an object
        return
        }

    bail_rtnval 2 "$1 ($ob) is not a thinobject or was not found"
    }


## parse options, which must precede target and (optional) class:
while [ -n "$1" -a ${1#-} != $1 ]; do

    opt=$1 && shift

    if [ "$opt" == "--hide" -o "$opt" == "--shadow" ]
        then
        ## create object as dotted directory
        TOB_NEW_DOTDIR=1

    elif [ "$opt" == "--no-hide" -o "$opt" == "--no-shadow" ]; then
        ## create object directly, not dotted...
        unset TOB_NEW_DOTDIR

    elif [ "$opt" == "-a" -o "$opt" == "--hide-attr" ]; then
        ## create object directly, not dotted...
        unset TOB_DOT_ATTR

    elif [ "$opt" == "-A" -o "$opt" == "--no-hide-attr" ]; then
        ## create object directly, not dotted...
        unset TOB_DOT_ATTR

    elif [ "$opt" == "-m" -o "$opt" == "--init-method" ]; then
        test -n "$1" || bail "missing argument for --init-method or -m option"
        TOB_NEW_INIT_METHOD=$1 && shift

    elif [ "$opt" == "-v" -o "$opt" == "--verbose" ]; then
        VERBOSE=1

    elif [ "$opt" == "-V" -o "$opt" == "--no-verbose" ]; then
        unset VERBOSE

    elif [ "$opt" == "-d" -o "$opt" == "--debug" ]; then
        DEBUG=1

    elif [ "$opt" == "-D" -o "$opt" == "--no-debug" ]; then
        unset DEBUG

    elif [ "$opt" == "-h" -o "$opt" == "--help" ]; then
        manpage
        exit 0
    
    else
        bail "unsupported option $opt"
    fi
done

## required argument specifying the target object to be created:
target=$1 && shift
test -n "$target" ||
    bail "no target specified for object creation"

## check if the target is already a thinobject:
tob -q $target.tob > /dev/null &&
    bail $target already exists as a thinobject

## ASSERT: target is not a thinobject

## specify class of the new object, or it defaults to Object
class=$1 && shift
test -n "$class" || class=Object

## check that class can be resolved:
check_class($class) ||
    bail thinobject class $class not found

for lib in ${LIB[@]}; do
    for root in ${ROOT[@]}; do
        classpath=$lib/$root/$class
        test -d $classpath && break 2
    done
done

test -d $classpath ||
    bail unable to resolve class $class

## ASSERT: class resolves

test "$TOB_NEW_INIT_METHOD" == "" && return 0

check_init_method($class) 
## (note: any remaining arguments will be passed to an init method, if called)

## try to handle target as a set of cases:

unset DO

if test ! -e $target; then
    test -n "$VERBOSE" &&
        echo target does not exist

    ## create the object as an ordinary or hidden directory:
    if test -n "$TOB_NEW_DOTDIR"; then
        DO=CREATE_DIR
    elif test "$TOB_NEW_DOTDIR" == "1"; then
        DO=CREATE_DOT_DIR
    else
        bail unexpected value of variable TOB_NEW_DOTDIR: $TOB_NEW_DOTDIR
    fi

elif test -L $target; then
    test -n "$VERBOSE" &&
        echo target is a symlink
    bail $target is a symlink, so no thinobject will be created

elif test -f $target; then
    test -n "$VERBOSE" &&
        echo target is an ordinary file
    DO=CREATE_DOT_DIR

elif test -d $target; then
    test -n "$VERBOSE" &&
        echo target is a directory
    if test -n "$TOB_NEW_DOTDIR"; then
        DO=USE_DIR
    elif test "$TOB_NEW_DOTDIR" == "1"; then
        DO=CREATE_DOT_DIR
    else
        bail unexpected value of variable TOB_NEW_DOTDIR: $TOB_NEW_DOTDIR
    fi

fi

## next, do what variable DO says to do:
if test -z "$DO"; then
    bail internal error: variable DO is not set
elif test $DO == USE_DIR; then
    tob=$target
elif test $DO == CREATE_DIR; then
    tob=$target
    test -d $tob &&
        bail thinobject directory $tob already exists
    test $VERBOSE && echo creating new thinobject $tob
    mkdir $tob ||
        bail failed to create thinobject directory: $target
elif test $DO == CREATE_DOT_DIR; then
    ## create potential tob by "dotting" target:
    if [ ${target/\/} == $target ]; then # no slash in target
        tob=.$target
    else # target has a slash in it
        tob=${target%\/*}/.${target/*\//}
    fi
    test -d $tob &&
        bail thinobject directory $tob already exists for $target
    test $VERBOSE && echo creating new thinobject $tob for $target
    mkdir $tob ||
        bail failed to create thinobject directory $tob for $target
else
    bail internal error: unknown value for DO variable: $DO
fi

## ASSERT: directory $tob exists, but no class link is defined

test -d $tob && test ! -e $tob/^ && test ! -e $tob/.^ ||
    bail class link $tob/^ or $tob/.^ already exists

## next, create the class link

test $VERBOSE && echo creating new object $tob
/bin/mkdir $tob
ln -s $class $tob/^
## check for and copy class .@uri property to object:
test -e $class/.@uri && cp $class/.@uri $tob/

## ASERT: class link is set; search for new method, else done
isa=$tob/^
while [ -e $isa ]; do ## look for new method
    if [ -d $isa ]; then # parent class methods directory
        test -e $isa/new && { # new method found!
            $isa/new $tob "$@" && exit 0 # all done!
            }
    else ## monolithic parent class handler
        if [ -x $isa ]; then ## handler is executable
            # invoke handler, grab exitcode
            $isa new $ob $args "$@"
            exitcode=$?
        else
            ## as noted above, not sure if this bail-out is right to do...
            bail "ERROR: $isa handler not executable"
        fi
    fi
    isa=$isa/^
done
        
test -x $tob/^/new || exit 0 # no new method
$tob/^/new $tob "$@" && exit 0 # all done!
## ASSERT: the ob.new method failed, so clean up
exec /usr/local/bin/thinob $ob.delete

# echo .
# echo OBJECT: $ob
# echo METHOD: $method

resolve_ob_to_tob $ob
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



##############
## manpage follows
##############
NAME
    thinob-new -- create a new thinobject
SYNOPSIS
    thinob-new [OPTIONS] TARGET [CLASS] 

DESCRIPTION
    Exit with status 1 if TARGET is already a thinobject (or even if it
    looks like one).

    Create or make TARGET a thinobject of a given class, or of class Object
    if not specified.

    Several possibilities may exist to create a new thinobject, based on
    existence and type of the target and upon several options.

    If TARGET does not exist, mkdir TARGET/ and set a symlink to the class
    named TARGET/.^.

    If TARGET is a directory, create symlink TARGET/.^ pointing to the class.

    If TARGET is a file, mkdir .TARGET/ and .TARGET/.^ as above.

    Some options may modify these behaviors; see below.

RETURN VALUE
    0   ok, target thinobject was created
    1   some error occurred

OPTIONS
    The following options may be used to control behavior, or the indicated
    environment variables may be used directly, e.g., to implement default 
    behaviors.

    -s
    --hide
    --shadow
    create the object as a "dot directory", i.e., hidden, perhaps shadowing 
    a regular file or directory.  Sets variable TOB_NEW_DOTDIR.

    -S
    --no-hide
    --no-shadow
    create the object as a normal directory, not hidden and not shadowing
    anything.  Unsets variable TOB_NEW_DOTDIR.

    -a
    --hide-attr
    create symbolic link to thinobject class as .^, not ^.  Sets/uses 
    variable TOB_HIDE_ATTR.

    -A
    --no-hide-attr
    create symbolic link to thinobject class as ^.  Unsets variable
    TOB_HIDE_ATTR.

    -m METHOD
    --init-method METHOD
    invoke the given method after the thinobject is created, passing any
    remaining arguments to the method.  Sets variable TOB_NEW_INIT_METHOD.
    The operation fails (and no thinobject is created) if the specified
    method is not found.  By default, if the variable is not set, the
    init method is invoked if present.  Specify the option or set the
    variable to a blank/empty value to avoid running any method.

    -d
    --debug
    turn on debug output (sets variable DEBUG)

    -D
    --no-debug
    turn on debug output (unsets variable DEBUG)

    -v
    --verbose
    turn on verbose output (sets variable VERBOSE)

    -V
    --no-verbose
    turn off verbose output (unsets variable VERBOSE)

    -h
    --help
    show this help screen (manpage)

SEE ALSO
    Each thinobject class is *supposed to* provide a help method, and
    a --help option to each of its methods.

BUGS
    Probably plenty.  This is an experimental system, with many details
    remaining to flesh out and/or fix.

AUTHOR
    Ken Irving <fnkci@uaf.edu> (c) 2009
END_OF_MANPAGE

