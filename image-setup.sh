#!/bin/bash

set -e
trap 'echo "[ERROR] Error in line $LINENO when executing: $BASH_COMMAND"' ERR

export DEBIAN_FRONTEND=noninteractive

rm -rf /utemp
mkdir -p /utemp
cd /utemp

# set password for pi user
echo "pi:adsb123" | chpasswd

# for good measure, blacklist SDRs ... we don't need these kernel modules
# this isn't really necessary but it doesn't hurt
echo -e 'blacklist rtl2832\nblacklist dvb_usb_rtl28xxu\nblacklist rtl8192cu\nblacklist rtl8xxxu\n' > /etc/modprobe.d/blacklist-rtl-sdr.conf

# mask services we don't need on this image
systemctl mask dump1090-fa
systemctl mask dump1090
systemctl mask dump1090-mutability
systemctl disable dphys-swapfile.service
systemctl disable apt-daily.timer
systemctl disable apt-daily-upgrade.timer
systemctl disable man-db.timer

if ! grep -qs -e '/tmp' /etc/fstab; then
cat >> /etc/fstab <<EOF
tmpfs /tmp tmpfs defaults,noatime,nosuid,size=100M	0	0
tmpfs /var/tmp tmpfs defaults,noatime,nosuid,size=100M	0	0
tmpfs /var/log tmpfs defaults,noatime,nosuid,size=50M	0	0
tmpfs /var/lib/systemd/timers tmpfs defaults,noatime,nosuid,size=50M	0	0
EOF
fi

echo adsbexchange > /etc/hostname
touch /boot/adsb-config.txt # canary used in some scripting if it's the adsbexchange image

mv /etc/cron.hourly/fake-hwclock /etc/cron.daily || true

pushd /etc/cron.daily
rm -f apt-compat bsdmainutils dpkg man-db
popd


# enable services
systemctl enable \
    adsbexchange-first-run.service \
    adsbx-zt-enable.service \
    readsb.service \
    adsbexchange-mlat.service \
    adsbexchange-feed.service \
    ssh


if grep -qs -e bullseye /etc/os-release; then
    wget -O piaware-repo.deb https://flightaware.com/adsb/piaware/files/packages/pool/piaware/p/piaware-support/piaware-repository_7.1_all.deb
elif grep -qs -e buster /etc/os-release; then
    wget -O piaware-repo.deb https://flightaware.com/adsb/piaware/files/packages/pool/piaware/p/piaware-support/piaware-repository_6.1_all.deb
else
    wget -O piaware-repo.deb https://flightaware.com/adsb/piaware/files/packages/pool/piaware/p/piaware-support/piaware-repository_5.1_all.deb
fi
dpkg -i piaware-repo.deb

curl https://install.zerotier.com  -o install-zerotier.sh
sed -i -e 's#while \[ ! -f /var/lib/zerotier-one/identity.secret \]; do#\0 break#' install-zerotier.sh
bash install-zerotier.sh

systemctl disable zerotier-one

apt update
apt remove -y g++ libraspberrypi-doc gdb
apt dist-upgrade -y

temp_packages="git make gcc libusb-1.0-0-dev librtlsdr-dev libncurses5-dev zlib1g-dev python3-dev python3-venv"
packages="chrony librtlsdr0 lighttpd zlib1g dump978-fa soapysdr-module-rtlsdr socat netcat uuid-runtime rtl-sdr beast-splitter"
packages+=" curl uuid-runtime jq gzip dnsutils perl bash-builtins" # for adsbexchange-stats, avoid invoking apt install gain

apt install --no-install-recommends --no-install-suggests -y $packages $temp_packages

apt purge -y piaware-repository
rm -f /etc/apt/sources.list.d/piaware-*.list

mkdir -p /adsbexchange/
rm -rf /adsbexchange/update
git clone --depth 1 https://github.com/ADSBexchange/adsbx-update.git /adsbexchange/update
rm -rf /adsbexchange/update/.git

bash /adsbexchange/update/update-adsbx.sh

git clone --depth 1 https://github.com/dstreufert/adsbx-webconfig.git
pushd adsbx-webconfig
bash install.sh
popd

bash -c "$(curl -L -o - https://github.com/wiedehopf/graphs1090/raw/master/install.sh)"
#make sure the symlinks are present for graphs1090 data collection:
ln -snf /run/adsbexchange-978 /usr/share/graphs1090/978-symlink/data
ln -snf /run/readsb /usr/share/graphs1090/data-symlink/data

bash -c "$(curl -L -o - https://github.com/wiedehopf/adsb-scripts/raw/master/autogain-install.sh)"

apt remove -y $temp_packages
apt autoremove -y
apt clean

# delete var cache
#rm -rf /var/cache/*
# Regenerate man database.
/usr/bin/mandb

sed -i -e 's#^driftfile.*#driftfile /var/tmp/chrony.drift#' /etc/chrony/chrony.conf

# config symlinks
ln -sf /boot/adsbx-978env /etc/default/dump978-fa
ln -sf /boot/adsbx-env /etc/default/readsb
ln -sf /boot/adsb-config.txt /etc/default/adsbexchange

cd /
rm -rf /utemp
