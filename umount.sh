#!/bin/bash

if ! [[ -f ./useloop ]]; then
    echo /dev/loop4 > useloop
fi
loop=$(cat ./useloop)

umount root/dev/pts
umount root/dev root/proc root/boot
umount root
losetup -d $loop
