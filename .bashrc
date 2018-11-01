# .bashrc for the main thinobject development directory, at ken@hayes

thislib=$PWD/lib:

test "${TOBLIB/$thislib/}" = "$TOBLIB" && TOBLIB+=$thislib
test -n "$TOBLIB" || TOBLIB=$thislib
export TOBLIB

thispath=$PWD/bin
test "${PATH/$thispath/}" = "$PATH" && PATH=$thispath:$PATH
export PATH

command_not_found_handle () { exec tob "$@"; }

