# .bashrc for the main thinobject development directory, at ken@hayes

thislib=/home/ken/proj/thinobject/src/lib:

test "${TOBLIB/$thislib/}" = "$TOBLIB" && TOBLIB+=$thislib
test -n "$TOBLIB" || TOBLIB=$thislib
export TOBLIB

thispath=/home/ken/proj/thinobject/src/bin
test "${PATH/$thispath/}" = "$PATH" && PATH=$thispath:$PATH
export PATH

command_not_found_handle () { exec tob "$@"; }

