#!/bin/bash

set -e
trap 'echo "[ERROR] Error in line $LINENO when executing: $BASH_COMMAND"' ERR

if [ "$(id -u)" != "0" ]; then
    echo "This script must be run using sudo or as root (only root can do the loop setup and mounting of the image)" 1>&2
    exit 1
fi

if [[ -z $1 ]] || [[ -z $2 ]]; then
    echo "usage: ./create-image <template-image> <image>"
    exit 1
fi
if [[ $2 =~ ^[0-9]*[0-9]\.[0-9]$ ]]; then
    version="$2.$(date +%y%m%d -d now)"
    image="adsbx-$version.img"
else
    image="$2"
    if [[ -n $3 ]] && [[ $3 =~ ^[0-9]*[0-9]\.[0-9]$ ]]; then
        version="$3.$(date +%y%m%d -d now)"
    else
        if grep bullseye <<< "$1"; then
            version="8.2.$(date +%y%m%d -d now)"
        else
            version="8.1.$(date +%y%m%d -d now)"
        fi
    fi
fi

mkdir -p ./root
chown root:root ./root

if true; then
    rm -f "${image}"
    cp -f "$1" "${image}"
    ./growimage.sh "${image}" 4000M
    ./mount.sh "${image}"
fi

bootfs=root/boot
if grep -qs bookworm root/etc/os-release; then
    bootfs=root/boot/firmware
fi

echo "$version" > root/boot/adsbx-version

mkdir -p root/adsbexchange/image-setup
init=/adsbexchange/image-setup/image-setup.sh
cp -T -f image-setup.sh "./root/$init"
# the chroot needs name resolution; the image keeps its own resolv.conf afterwards
if [[ -e root/etc/resolv.conf || -L root/etc/resolv.conf ]]; then
    mv -f root/etc/resolv.conf root/etc/resolv.conf.image
fi
cp -L /etc/resolv.conf root/etc/resolv.conf
env -i /usr/sbin/chroot --userspec=root:root ./root /bin/bash -l "$init"
rm -f root/etc/resolv.conf
if [[ -e root/etc/resolv.conf.image || -L root/etc/resolv.conf.image ]]; then
    mv -f root/etc/resolv.conf.image root/etc/resolv.conf
fi

# don't delete these file, we need wpa conf from webconfig which has already set this file
#rm -rf root/boot/wpa_supplicant.conf
#rm -rf root/etc/wpa_supplicant/wpa_supplicant.conf

rm -f root/boot/adsbx-uuid
rm -rf root/var/lib/zerotier-one/identity.*
rm -rf root/var/lib/zerotier-one/authtoken.secret
rm -rf root/var/lib/tailscale/tailscaled.state
rm -rf root/var/lib/collectd/rrd/*
rm -rf root/etc/ssh/ssh_host_*_key*
rm -rf root/home/pi/.bash_history
rm -rf root/home/pi/.local
rm -rf root/root/.bash_history
rm -rf root/usr/local/share/tar1090/git
rm -rf root/usr/local/share/tar1090/git-db
rm -rf root/tmp/*
rm -rf root/var/tmp/*
rm -rf root/var/cache/apt
rm -rf root/var/lib/apt/lists/*
rm -rf root/usr/share/graphs1090/git/

# limit the first-boot root expansion to 8000 MiB on images that expand through init_resize.sh
if grep -qs init_resize.sh "$bootfs/cmdline.txt"; then
    cp root/usr/lib/raspi-config/init_resize.sh root/usr/local/bin/limited_expand.sh
    sed -i -e 's|/usr/lib/raspi-config/init_resize.sh|/usr/local/bin/limited_expand.sh|' "$bootfs/cmdline.txt"
    sed -i -e 's|/usr/lib/raspi-config/init_resize\\.sh|/usr/local/bin/limited_expand\\.sh|' root/usr/local/bin/limited_expand.sh
    sed -i -e 's/sleep 5/sleep 1/g' root/usr/local/bin/limited_expand.sh
    sed -i -e 's#TARGET_END=$((ROOT_DEV_SIZE - 1))#\0\
MAX_TARGET_END=$((8000 * 1024 * 1024 / 512))\
if [ "$TARGET_END" -gt "$MAX_TARGET_END" ]; then TARGET_END=$MAX_TARGET_END; fi\
#g' root/usr/local/bin/limited_expand.sh
else
    echo "cmdline.txt does not run init_resize.sh; the root partition is left as the base image's first boot leaves it"
fi

./umount.sh

# skip auto expansion, we use the autoexpand the rpi image comes with and modify it
./pishrink-custom.sh -sv "${image}"

./mount.sh "${image}"
dd if=/dev/zero of=root/zeros bs=1M status=progress &>/dev/null || true
rm -rf root/zeros
./umount.sh "${image}"

echo --------------------------------------------
echo --------------------------------------------
echo --------------------------------------------
echo --------------------------------------------
echo --------------------------------------------
echo "Image creation finished! Version: $version"
echo --------------------------------------------
echo --------------------------------------------
echo --------------------------------------------
echo --------------------------------------------
echo --------------------------------------------
