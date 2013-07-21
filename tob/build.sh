#!/bin/bash

path=${0%/*}

order=(
    shebang
    prelude
    warn
    error
    debug
    parse-query
    resolve-query
    resolve-path
    resolve-anonymous-object
    resolve-named-object
    init-libraries
    resolve-library-type
    resolve-attr-search-paths
    resolve-search-paths
    resolve-declaration
    cull-duplicate-paths
    resolve-method
    resolve-method-declaration
    resolve-type-method
    resolve-wrapper-method
    check-chaining-directives
    parse-chain-args
    resolve-chained-methods
    run-chained-methods
    TOB-resolve-method
    TOB-get-attribute
    TOB-get-symvar
    main
    call-main
    manpage
)

for f in ${order[*]}; do 
    cat $path/$f
    printf "\n"
done

