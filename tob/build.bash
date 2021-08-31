#!/usr/bin/env bash

path=${0%/*}

for f in $(<@ORDER); do 
    cat $path/$f
done

