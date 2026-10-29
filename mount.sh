#!/bin/bash

if [[ -z $1 ]]; then
    echo insufficient arguments
    exit 1
fi
if ! [[ -f ./useloop ]]; then
    echo /dev/loop4 > useloop
fi

image="$1"
loop=$(cat ./useloop)

p1=${loop}p1
p2=${loop}p2

#tear down old mount
./umount.sh

losetup $loop -P $image

mkdir -p root
mount $p2 root
# bookworm mounts the boot partition at /boot/firmware
if grep -qs bookworm root/etc/os-release; then
    mount $p1 root/boot/firmware
else
    mount $p1 root/boot
fi

mount --bind /dev root/dev
mount --bind /dev/pts root/dev/pts
mount proc -t proc root/proc

