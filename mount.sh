#!/bin/bash

if [[ -z $1 ]]; then
    echo insufficient arguments
    exit 1
fi

image="$1"
loop=$(cat ./useloop)

p1=${loop}p1
p2=${loop}p2

#tear down old mount
umount boot root
losetup -d $loop

losetup $loop -P $image

mount $p1 boot
mount $p2 root
