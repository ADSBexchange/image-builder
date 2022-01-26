#!/bin/bash

if [[ -z $1 ]] || [[ -z $2 ]]; then
    echo insufficient arguments
    exit 1
fi

loop=$(cat ./useloop)
image="$1"
PART_NUM=2

truncate -s "$2" "$image"

fdisk "$image" <<EOF
  p
  d
  $PART_NUM
  n
  p
  $PART_NUM

  p
  w
EOF

resize2fs
