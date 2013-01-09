#!/bin/bash

path=${0%/*}

order=(shebang
    prelude
    warn
    error
    debug
    parse-query
    resolve-query
    resolve-path
    resolve-anonymous-object
    resolve-named-object
    resolve-library
    resolve-attr-search-paths
    resolve-search-paths
    resolve-declaration
    cull-duplicate-paths
    resolve-method-path
    resolve-chained-methods
    check-chaining-directives
    parse-chain-args
    run-chained-methods
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

