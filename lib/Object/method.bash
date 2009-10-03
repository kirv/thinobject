#!/bin/bash

cd $tob_path || exit 1

if test -L .^; then
    class=.^
elif test -L ^; then
     class=^
fi

declare -a classlinks
while [ -L $class ]; do
    classlink=$(/bin/readlink -f $class)
    classlinks=($classlinks $classlink)
    if test -L $class/.^; then
        class=$class/.^
    elif test -L $class/^; then
         class=$class/^
    else
        break
    fi
done

for class in ${classlinks[@]}; do
    echo $class
    for f in $class/*; do
        test -f $f && test -x $f && {
            m=${f##*/}
            if test -z $method_$m; then
                declare -a $method_$m=$m
            else
                m=SUPER::$m
            fi
            echo $m
            }
    done
done
