#!/bin/bash

set -e
trap 'echo "[ERROR] Error in line $LINENO when executing: $BASH_COMMAND"' ERR

if [[ -z $1 ]] || [[ -z $2 ]]; then
    echo "usage: ./create-image <template-image> <image>"
    exit 1
fi
image="$2"

if true; then
    rm -f "${image}"
    cp -f "$1" "${image}"
    ./growimage.sh "${image}" 2500M
    ./mount.sh "${image}"
fi


rm -rf root/adsbexchange
mkdir -p root/adsbexchange
git clone --depth 1 https://github.com/ADSBexchange/adsbx-update.git root/adsbexchange/update
rm -rf root/adsbexchange/update/.git

find skeleton -type d | cut -d / -f1 --complement | grep -v '^skeleton' | xargs -t -I '{}' -s 2048 mkdir -p root/'{}'
find skeleton -type f | cut -d / -f1 --complement | xargs -I '{}' -s 2048 cp -a -T --remove-destination -v skeleton/'{}' root/'{}'

cat >> root/etc/fstab <<EOF
tmpfs /tmp tmpfs defaults,noatime,nosuid,size=100M	0	0
tmpfs /var/tmp tmpfs defaults,noatime,nosuid,size=100M	0	0
tmpfs /var/lib/chrony tmpfs defaults,noatime,nosuid,size=50M	0	0
tmpfs /var/log tmpfs defaults,noatime,nosuid,size=50M	0	0
EOF

mv root/etc/cron.hourly/fake-hwclock root/etc/cron.weekly/fake-hwclock

cat > /etc/cron.d/weekly_reboot <<EOF
# reboot every Monday at 02:42 in the morning
42 2 * * 1 root /usr/sbin/reboot
EOF

mkdir -p root/adsbexchange/image-setup
init=/adsbexchange/image-setup/image-setup.sh
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
