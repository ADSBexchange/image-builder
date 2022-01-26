#!/bin/bash

loop=$(cat ./useloop)

umount boot root
losetup -d $loop
