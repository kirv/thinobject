#!/usr/bin/env bash

path=${0%/*}

echo PATH: $path
exit

for f in $(<@order); do 
    cat $path/$f
done

