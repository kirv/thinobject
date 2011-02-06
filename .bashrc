# .bashrc for the main thinobject development directory, at ken@hayes
export TOBLIB=/home/ken/proj/thinobject/src/lib:$TOBLIB
export PATH=/home/ken/proj/thinobject/src/bin:$PATH
command_not_found_handle () { exec tob "$@"; }

