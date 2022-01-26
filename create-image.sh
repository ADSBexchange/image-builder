#!/bin/bash
set -e
if [[ -z $1 ]] || [[ -z $2 ]]; then
    echo "usage: ./create-image <template-image> <image>"
    exit 1
fi
image="$2"

rm -f "${image}"
cp -f "$1" "${image}"
./growimage.sh "${image}" 2G

./mount.sh "${image}"

find skeleton -type f | cut -d / -f1 --complement | xargs -I '{}' -s 2048 cp -a -T --remove-destination -v skeleton/'{}' root/'{}'

mkdir -p ./root/image-setup/
init=/image-setup/image-setup.sh
cp -T -f image-setup.sh "./root/$init"
env -i /usr/sbin/chroot --userspec=root:root ./root /bin/bash -l "$init"

rm -rf root/utemp

rm -f root/boot/adsbx-uuid
rm -rf root/boot/wpa_supplicant.conf

rm -rf root/etc/wpa_supplicant/wpa_supplicant.conf
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
dd if=/dev/zero of=root/zeros bs=1M status=progress || true
rm -rf root/zeros

./umount.sh

./pishrink-custom.sh "${image}"

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
