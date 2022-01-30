#!/bin/bash

set -e
trap 'echo "[ERROR] Error in line $LINENO when executing: $BASH_COMMAND"' ERR

img="$1"

tmp=.extra-shrink
mkdir -p $tmp/from $tmp/to

loop0=$(losetup -f)

losetup -D
losetup $loop0 -P "$img"

free=$(( 4096 * $(tune2fs -l ${loop0}p2 | grep -i 'Free blocks' | cut -d : -f2 | tr -d ' ') ))

oldtotal=$(du -b "$img" | tr '[:space:]' ' ' | cut -d ' ' -f 1)

free=$(( free - 100 * 1024 * 1024 ))
if (( free < 0 )); then
    echo "extra shrink can't help with this image, nothing to shrink"
    exit 0
fi

echo "Trying to shrink image by $(( $free / 1024 / 1024 )) MB"

newtotal=$(( oldtotal - free ))

rm -f $tmp/img
dd if="$img" of=$tmp/img bs=1M count=500

truncate -s $newtotal $tmp/img

fdisk $tmp/img <<EOF
p
d
2
n
p
2
100000


p
w
EOF

loop1=$(losetup -f)
losetup $loop1 -P $tmp/img

mkfs.ext4 -F ${loop1}p2

mount ${loop0}p2 $tmp/from
mount ${loop1}p2 $tmp/to

echo Copying over files ...
tar -c $tmp/from -f - | dd status=progress | tar -f - --strip-components=2 -x -C $tmp/to

umount $tmp/from $tmp/to
losetup -D


echo extra-shrink is done: SUCCESS

mv $tmp/img "$img.es"
