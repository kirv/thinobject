#!/usr/bin/env bash

path=${0%/*}

for f in $(<@order); do 
    cat $path/$f
done

