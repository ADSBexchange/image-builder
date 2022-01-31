#!/bin/bash

set -e
trap 'echo "[ERROR] Error in line $LINENO when executing: $BASH_COMMAND"' ERR

if [[ -z $1 ]] || [[ -z $2 ]]; then
    echo insufficient arguments
    exit 1
fi
if ! [[ -f ./useloop ]]; then
    echo /dev/loop4 > useloop
fi

loop=$(cat ./useloop)
image="$1"
PART_NUM=2


./umount.sh

truncate -s "$2" "$image"

PART_START=$(parted $image -ms unit s p | grep "^${PART_NUM}" | cut -f 2 -d: | sed 's/[^0-9]//g')

fdisk "$image" <<EOF
  p
  d
  $PART_NUM
  n
  p
  $PART_NUM
  $PART_START

  p
  w
EOF


p1=${loop}p1
p2=${loop}p2
losetup $loop -P $image


e2fsck -f $p2
resize2fs $p2

./umount.sh
