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

    resolve_ob_to_tob $ob

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

# echo "    DEBUG: ob: $ob"
# echo "    DEBUG: method: $method"

if [ $method == 'new' -o $method == 'clone' ]; then

    ## new and clone both use the first argument as the class or the
    ## reference object, but may have some options before the argument:

    while [ "${1:0:1}" == "-" ]; do
        opt=$1 && shift
        case $opt in
        --hide|--hidden)
            HIDE_OBJECT=1
            ;;
        --shadow)
            SHADOW_A_FILE=1
            HIDE_OBJECT=1
            ;;
        --touch)
            TOUCH_FILE=1
            ;;
        *)
            echo unknown option: \"$opt\"
            show_usage
            exit 2
            ;;
        esac
    done

    ## create potential tob by "dotting" ob:
    if [ ${ob/\/} == $ob ]; then # no slash in ob
        tob=.$ob
    else # ob has a slash in it
        tob=${ob%\/*}/.${ob/*\//}
    fi

    test -e $tob &&
        bail "new: $tob already exists"

    if [ "$SHADOW_A_FILE" ]; then
        ## the file ob must exist or --touch specified...
        test -e $ob || { # no file or directory of this name
            test -n "$TOUCH_FILE" || ## --touch option not given
                bail "new: --shadow requires --touch if object doesn't exist"
            ## ASSERT: --shadow --touch options were given
            touch $ob
            }
        ## ASSERT: $ob exists and $tob does not yet exist
    else # don't shadow an existing file, but create object or .object
        test -e $ob && 
          # bail "new: $ob already exists as file, directory, or object"
            bail "new: $ob already exists"
        ## ASSERT: neither $ob nor $tob exists
        ## note that $tob is already the hidden object name
        test -z "$HIDE_OBJECT" && tob=$ob
        test -n "$TOUCH_FILE" && 
            bail "ERROR new: --touch option without --shadow" 
    fi
    ## ASSERT: $tob is the object to be created, and $ob may exist or not

  # echo nominal: $ob
  # echo _object: $tob
  # echo _method: $method

    test "$method" == "new" && {
        class="$1"; shift
        test -n $class || bail "no thinobject class specified!" 
        ## ASSERT class is specified

        ## resolve class path:
        if [ ${class#/} != $class ]; then # absolute path
            test ! "$NOT_STRICT" && 
                check_class $class || bail "ERROR new: invalid class library path: <$class>"
        else # relative path
            unset classpath
            for lib in ${LIB[@]}; do
                for root in ${ROOT[@]}; do
                  # echo CHECKING: $lib/$root/$class...
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
        test -e $class ||
            bail "ERROR new: class library $class not found"
        ## should perhaps do more validity testing of the class here

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
        test -L $ob2 && tob2=$(/bin/readlink -f $ob2) # resolve symlinked/aliased ob2
    
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
          # exec /usr/bin/find -L $* # follow symlinks by default!
            test $DEBUG -a $VERBOSE &&
                echo exec /usr/bin/find -follow -not -regex '.*/\..*' $*
            exec /usr/bin/find -follow -not -regex '.*/\..*' $* 2>/dev/null # follow symlinks by default!
        else # by default, show output without leading "./"
          # exec /usr/bin/find -L -printf "%P\n"
            test "$DEBUG" -a "$VERBOSE" &&
                echo exec /usr/bin/find -not -type d -not -regex '.*/\..*' -follow -printf "%P\n"
            exec /usr/bin/find -not -type d -not -regex '.*/\..*' -follow -printf "%P\n" 2>/dev/null
        fi
        }
    test $DEBUG -a $VERBOSE && echo exec /usr/bin/find $tob $*
    exec /usr/bin/find $tob $* 2>/dev/null
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

test "$method" == "delete" && { ## CAUTION!!
    if [ -z "$*" ]; then # no args, so delete object
        for f in $tob/*; do
            /bin/rm $f
        done
        /bin/rmdir $tob 
        /bin/rm $ob
    else
        for f in $*; do
            property=$tob/$f
            test "$VERBSOSE" && echo delete property $property
            if [ -f $property ]; then   # ordinary file
                /bin/rm $property
            elif [ -L $property ]; then # symlink
                /bin/rm $property
            elif [ -d $property ]; then # directory
                /bin/rmdir $property || bail "$property directory not empty"
            else                        # directory
                echo \"$property\" not found or at least not deleted...
            fi
        done
    fi
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

    -H
    --not-hidden
    with new or clone methods, create object directly, not as a dot-directory
    
    -T
    --no-touch
    with new or clone methods, create hidden object, don't touch nominal file
    
    -q
    --quiet
    suppress output to stderr on errors
    
OBJECT CREATION
    Built-in special methods new and clone create a new object of the given
    class or as a copy of the given object.  (They are ``special'' since
    they operate on objects which do not yet exist.)

    Note: The clone method is not yet supported.

    new [--hide|--hidden] [--shadow] [--touch] CLASS
        create a new object of class CLASS

    clone [--hide|--hidden] [--shadow] [--touch] OBJECT
        create a new object as a clone (copy) of OBJECT

    By default, the object is created as a directory, but the following
    options are supported:

        --hide
        --hidden
            create the object as a "dot directory" (i.e., as .ob/)
    
        --shadow
            create the object as a "dot directory" where a file or 
            directory of the same name (without the dot) exists
    
        --touch
            with --shadow, create a file (using touch) if it does not
            already exist
    
    After object creation, the ``new'' method of the class is invoked if
   it exists.

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

ENVIRONMENT VARIABLES
    The following variables are exported:

    tob_object -- the object name as passed to the thinob enabler

    tob_ob -- the nominal object name (may be partially resolved)

    tob_path -- the fully resolved object name

    tob_tob -- the fully resolved object name

    tob_method -- the invoked method

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

