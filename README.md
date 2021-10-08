# thinobject
object-oriented applications on the filesystem using simple conventions

**thinobject** uses (or abuses) symlinks, specifically *non-resolving symlinks*, in several ways. 

1. The **type** or **prototype** of an object is given by the value (e.g., obtained from *readlink()*) of the symlink named '^'.

  1. The value of a non-resolving symlink named **'^'** is the **type** of the thinobject object, where that type must be found in the thinobject type library identified in the TOBLIB envrironment variable.  A thinobject 'type' is a directory containing executable programs -- those programs are the **methods** that can be run by the object.  Other thinobject attributes might also be included in a type directory.
  
  1. If symlink ^ resolves to a directory, then that directory is the **prototype** of the thinobject object.  In turn, the prototype object itself (or its prototype, and so on) must have a non-resolving ^ symlink that identifies a valid thinobject type.  An object can **only** run methods that are defined in a thinobject type directory.  Executable programs in a prototype directory are not available as methods.  Other thinobject attributes in a prototype directory are available to the object with ^ pointing to that prototype.

thinobject relies on ^ symlinks -- **type links** -- to resolve methods for execution by an object.  The type links effectively are the equivalent of the shell **PATH** environment variable; where the shell uses a search in the PATH (colon-delimited) directories to resolve an executable program of the given name, thinobject looks in thinobject type directories found by following ^ symlinks to resolve executable programs as methods of the object.

The *thinobject handler* or *executive*, e.g., a shell script named **tob** and found in PATH, gets a hook to badly-formed command line commands via the bash **command_not_found_handle()** function, and tries to reinterpret the bad command using the form **OBJECT.METHOD**.  The object is resolved relative to where the command is issued, perhaps requiring substituting '.' characters with '/'.  The requested method is resolved using the object's ^ type link, and is exectuted if found.

That's kind of it, I think.  thinobject provides a way to find exectutable programs (methods) by following type links defined in symlinks named ^ in object directories.  It gets there by parsing a command of the form *OBJECT.METHOD [ARGS...]* to identify the object, then its type, and then by resolving the given method via that type.


