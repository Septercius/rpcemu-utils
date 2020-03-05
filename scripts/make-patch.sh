#!/bin/bash

touch ./rpcemu-0.9.2-mac-patch-vX.patch

for i in $1/* ; do
cat $i >> ./rpcemu-0.9.2-mac-patch-vX.patch
done

