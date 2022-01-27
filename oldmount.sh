#!/bin/bash

if [[ -z $1 ]]; then
    echo insufficient arguments
    exit 1
fi

image="$1"
loop=/dev/loop2

p1=${loop}p1
p2=${loop}p2

umount oldboot oldroot
losetup -d $loop

losetup $loop -P $image

mount $p2 oldroot
mount $p1 oldroot/boot
