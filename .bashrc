# .bashrc for the main thinobject development directory, at ken@hayes
<<<<<<< HEAD
export TOBLIB=/home/ken/proj/thinobject/src/lib
=======
export TOBLIB=/home/ken/proj/thinobject/src/lib:$TOBLIB
>>>>>>> c3ea37b24e96456f9f5929aef073d355b905e6cc
export PATH=/home/ken/proj/thinobject/src/bin:$PATH
command_not_found_handle () { exec tob "$@"; }

