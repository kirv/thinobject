#!/bin/bash

path=${0%/*}

order=(shebang
    prelude
    warn
    error
    debug
    resolve-library
    resolve-search-paths
    resolve-declaration
    resolve-query
    cull-duplicate-paths
    resolve-method-path
    TOB-resolve-method-path
    TOB-get-attribute
    main
    )

for f in ${order[*]}; do 
    cat $path/$f
    printf "\n"
done

printf "%s\n\n" 'main "$@"'

cat $path/manpage

