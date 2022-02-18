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
[[ $2 =~ ^[0-9]*[0-9]\.[0-9]$ ]] && image="adsbx-$2.$(date +%y%m%d -d now).img" || image="$2"

mkdir -p ./root
chown root:root ./root

if true; then
    rm -f "${image}"
    cp -f "$1" "${image}"
    ./growimage.sh "${image}" 2500M
    ./mount.sh "${image}"
fi

echo $2.$(date +%y%m%d -d now) > root/boot/adsbx-version

find skeleton -type d | cut -d / -f1 --complement | grep -v '^skeleton' | xargs -t -I '{}' -s 2048 mkdir -p root/'{}'
find skeleton -type f | cut -d / -f1 --complement | xargs -I '{}' -s 2048 cp -T --remove-destination -v skeleton/'{}' root/'{}'

mkdir -p root/adsbexchange/image-setup
init=/adsbexchange/image-setup/image-setup.sh
cp -T -f image-setup.sh "./root/$init"
env -i /usr/sbin/chroot --userspec=root:root ./root /bin/bash -l "$init"

# don't delete these file, we need wpa conf from webconfig which has already set this file
#rm -rf root/boot/wpa_supplicant.conf
#rm -rf root/etc/wpa_supplicant/wpa_supplicant.conf

rm -f root/boot/adsbx-uuid
rm -rf root/var/lib/zerotier-one/identity.*
rm -rf root/var/lib/zerotier-one/authtoken.secret
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

# modify rpi image autoexpand
cp root/usr/lib/raspi-config/init_resize.sh root/usr/local/bin/limited_expand.sh
sed -i -e 's|/usr/lib/raspi-config/init_resize.sh|/usr/local/bin/limited_expand.sh|' root/boot/cmdline.txt
sed -i -e 's|/usr/lib/raspi-config/init_resize\\.sh|/usr/local/bin/limited_expand\\.sh|' root/usr/local/bin/limited_expand.sh
sed -i -e 's/sleep 5/sleep 1/g' root/usr/local/bin/limited_expand.sh
sed -i -e 's#TARGET_END=$((ROOT_DEV_SIZE - 1))#\0\
MAX_TARGET_END=$((8000 * 1024 * 1024 / 512))\
if [ "$TARGET_END" -gt "$MAX_TARGET_END" ]; then TARGET_END=$MAX_TARGET_END; fi\
#g' root/usr/local/bin/limited_expand.sh

./umount.sh

# skip auto expansion, we use the autoexpand the rpi image comes with and modify it
./pishrink-custom.sh -sv "${image}"

./mount.sh "${image}"
dd if=/dev/zero of=root/zeros bs=1M status=progress || true
rm -rf root/zeros
./umount.sh "${image}"

echo --------------------------------------------
echo --------------------------------------------
echo --------------------------------------------
echo --------------------------------------------
echo --------------------------------------------
echo Image creation finished!
echo --------------------------------------------
echo --------------------------------------------
echo --------------------------------------------
echo --------------------------------------------
echo --------------------------------------------
