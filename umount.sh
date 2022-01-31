#!/bin/bash

set -e
trap 'echo "[ERROR] Error in line $LINENO when executing: $BASH_COMMAND"' ERR

if ! [[ -f ./useloop ]]; then
    echo /dev/loop4 > useloop
fi
loop=$(cat ./useloop)

umount root/dev/pts || true
umount root/dev root/proc root/boot || true

if ! umount root && ! umount root 2>&1 | grep -qs -e 'not mounted'; then
    exit 1
fi

losetup -d $loop &>/dev/null || true

if losetup -a | grep $loop; then
    exit 1
fi
