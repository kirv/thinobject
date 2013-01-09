#!/usr/bin/python

# synopsis: Attr/Number.set VALUE

import sys, os

if len(sys.argv) < 2:
    sys.exit(1)

try:
    num = float(sys.argv[1])
except ValueError:
    sys.exit(2)

prec = 2

try:
    if os.environ.has_key('NUM_MIN'):
        if num < float(os.environ['NUM_MIN']):
            sys.exit(3)
    if os.environ.has_key('NUM_MAX'):
        if num > float(os.environ['NUM_MAX']):
            sys.exit(4)
    if os.environ.has_key('NUM_PREC'):
        prec = int(os.environ['NUM_PREC'])
except ValueError:
    sys.exit(5)

# assert: num is present, it's a float, and it's in range (if defined)

# pretty-print it for output:
numstr = "%.*f" % (prec,num,)

# look in envar TOB_method_paths for super.set, that is, the 2nd 'set'
super = 0
for path in os.environ['TOB_method_paths'].split(':'):
    method = path + '/set'
    if os.path.exists(method) and os.access(method, os.X_OK):
        if super == 1:
            os.execl(method, method, numstr)
        super += 1

