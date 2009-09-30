#!/bin/sh

# require class handlers & methods to be under this path
LIB=( ~/lib /usr/local/lib /home/.usr-local/lib /usr/lib )
ROOT=( thinob tob ThinObject )

function manpage() { # print manpage at end of this script...
    exec /usr/bin/awk '/^NAME$/{ok=1}ok' $0
    }

## provide a mechanism to back out of any changes if necessary:
dim -a rollback_commands
function rollback () {
    test -n "$VERBOSE" &&
        echo rolling back commands:
    for (( i=${#rollback_commands[@]}; $i > 0; i=$i - 1 )); do
        cmd="${rollback_commands[$i]}"
        test -n "$VERBOSE" &&
            echo executing rollback command: $cmd...
        $cmd || {
            echo failed to execute rollback command: $cmd
            exit 2
            }
    done
    }

function bail () {
    echo $* >&2
    test -n "$rollback_commands" &&
        rollback
    exit 1
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
        test -n "$1" ||
            bail "missing argument for --init-method or -m option"
        test "$1" == ${1#*/} ||
            bail init method cannot include a slash: $1
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

target=$1 && shift

## an argument specifying the target object to be created is required:
test -n "$target" ||
    bail "no target specified for object creation"

##  the target must not already be a thinobject:
tob -q $target.tob > /dev/null &&
    bail $target already exists as a thinobject

## second argument specifies class of the new object, or it defaults to Object
class=$1 && shift
test -n "$class" || class=Object

## check that class can be resolved:

for lib in ${LIB[@]}; do
    for root in ${ROOT[@]}; do
        classpath=$lib/$root/$class
        test -d $classpath && break 2
    done
done

test -d $classpath ||
    bail unable to resolve thinobject class $class

## ASSERT: class resolves

## use method 'init' by default if nothing is specified
test -z "$TOB_NEW_INIT_METHOD" && TOB_NEW_INIT_METHOD=init

unset init_method_path

## resolve init method unless blank value is specified:
test -n "$TOB_NEW_INIT_METHOD" && {
    searchpath=$classpath/^
    while test -d $searchpath/; do
        test -e $searchpath/$TOB_NEW_INIT_METHOD &&
            test -x $searchpath/$TOB_NEW_INIT_METHOD &&
                init_method_path=$searchpath/$TOB_NEW_INIT_METHOD &&
                    break
        searchpath=$searchpath/^
    done
    }

## check that init method exists unless blank value is specified:
test -n "$TOB_NEW_INIT_METHOD" && -n "$init_method_path" ||
    bail thinobject method $TOB_NEW_INIT_METHOD not found

## any remaining arguments will be passed to an init method, if called;
## but check that there are no more arguments if there's no init method 
test -z "init_method_path" && test -n "$1" &&
    bail error: extra arguments given: $*

## now try to handle target as a set of cases:

unset DO_THIS

if test ! -e $target; then
    test -n "$VERBOSE" &&
        echo target does not exist

    ## create the object as an ordinary or hidden directory:
    if test -n "$TOB_NEW_DOTDIR"; then
        DO_THIS=CREATE_DIR
    elif test "$TOB_NEW_DOTDIR" == "1"; then
        DO_THIS=CREATE_DOT_DIR
    else
        bail unexpected value of variable TOB_NEW_DOTDIR: $TOB_NEW_DOTDIR
    fi

elif test -L $target; then
    bail thinobject will not be created because target $target is a symlink

elif test -f $target; then
    test -n "$VERBOSE" &&
        echo target is an ordinary file
    DO_THIS=CREATE_DOT_DIR

elif test -d $target; then
    test -n "$VERBOSE" &&
        echo target is a directory
    if test -n "$TOB_NEW_DOTDIR"; then
        DO_THIS=USE_DIR
    elif test "$TOB_NEW_DOTDIR" == "1"; then
        DO_THIS=CREATE_DOT_DIR
    else
        bail unexpected value of variable TOB_NEW_DOTDIR: $TOB_NEW_DOTDIR
    fi

fi

## next, do what variable DO_THIS says to do:
if test -z "$DO_THIS"; then
    bail internal error: variable DO_THIS is not set

elif test $DO_THIS == USE_DIR; then
    tob=$target

elif test $DO_THIS == CREATE_DIR; then
    tob=$target
    test -d $tob &&
        bail thinobject directory $tob already exists
    test $VERBOSE &&
        echo creating new thinobject $tob
    mkdir $tob ||
        bail failed to create thinobject directory: $tob
    ${rollback_commands[ ${#rollback_commands[@]} ]}="rmdir $tob"

elif test $DO_THIS == CREATE_DOT_DIR; then
    ## create potential tob by "dotting" target:
    if test ${target/\/} == $target; then # no slash in target
        tob=.$target
    else # target has a slash in it
        ## insert dot after last slash:
        tob=${target%\/*}/.${target/*\//}
    fi
    test -d $tob &&
        bail thinobject directory $tob already exists for $target
    test $VERBOSE &&
        echo creating new thinobject $tob for $target
    mkdir $tob ||
        bail failed to create thinobject directory $tob for $target
    ${rollback_commands[ ${#rollback_commands[@]} ]}="rmdir $tob"

else
    bail internal error: unknown value for DO_THIS variable: $DO_THIS

fi

## ASSERT: directory $tob exists, but class link is not yet defined

test -d $tob && test ! -e $tob/^ && test ! -e $tob/.^ ||
    bail error: file $tob/^ or $tob/.^ already exists in place of class link

## next, create the class link

test $VERBOSE &&
    echo setting link to class $class in thinobject $tob for $target

classlink_name=^
test -n "$TOB_DOT_ATTR" && classlink_name=.^

ln -s $class $tob/$classlink_name ||
    bail failed to create symlink: ln -s $class $tob/$classlink_name
    
${rollback_commands[ ${#rollback_commands[@]} ]}="rm $tob/$classlink_name"

## check for uri property (@uri or .@uri) in class:
unset uri_source
test -e $classpath/.@uri && uri_source=$classpath/.@uri
test -e $classpath/@uri && uri_source=$classpath/@uri

## copy class uri property to thinobject:
test -e $uri_source && {
    uri_dest=@uri
    test -n "$TOB_DOT_ATTR" && uri_dest=.@uri
    cp $uri_source $tob/$uri_dest ||
        bail failed to copy class uri property $uri_source to $tob/$uri_dest
    ${rollback_commands[ ${#rollback_commands[@]} ]}="rm $tob/$uri_dest"
    }

## lastly, execute the init method, if defined & specified:

NEED TO DO!!!

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

test -z "$ob" -o -z "$tob" &&
    bail "no object was parsed"

test ! -d $tob &&
    bail "ERROR: $tob is not a directory"

test -z "$method" &&
    bail "no method specified for $ob"

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

