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

# grow the file to $2 (never shrink it) and extend the root partition to the end
target=$(numfmt --from=iec "$2")
if (( $(stat -c %s "$image") < target )); then
    truncate -s "$target" "$image"
fi
parted -s "$image" resizepart $PART_NUM 100%

p1=${loop}p1
p2=${loop}p2
losetup $loop -P $image


e2fsck -fp "$p2" || [ $? -le 1 ]
resize2fs $p2

./umount.sh
