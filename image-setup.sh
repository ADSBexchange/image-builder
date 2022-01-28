#!/bin/bash

set -e
trap 'echo "[ERROR] Error in line $LINENO when executing: $BASH_COMMAND"' ERR

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
tmpfs /var/lib/chrony tmpfs defaults,noatime,nosuid,size=50M	0	0
tmpfs /var/log tmpfs defaults,noatime,nosuid,size=50M	0	0
tmpfs /var/lib/systemd/timers tmpfs defaults,noatime,nosuid,size=50M	0	0
EOF
fi

echo adsbexchange > /etc/hostname

# enable services
systemctl enable \
    adsbexchange-first-run.service \
    adsbx-zt-enable.service \
    readsb.service \
    adsbexchange-mlat.service \
    adsbexchange-feed.service \
    ssh \


wget -O piaware-repo.deb https://flightaware.com/adsb/piaware/files/packages/pool/piaware/p/piaware-support/piaware-repository_6.1_all.deb
dpkg -i piaware-repo.deb

curl https://install.zerotier.com  -o install-zerotier.sh
sed -i -e 's#while \[ ! -f /var/lib/zerotier-one/identity.secret \]; do#\0 break#' install-zerotier.sh
bash install-zerotier.sh

systemctl disable zerotier-one

apt update
apt remove -y g++ libraspberrypi-doc gdb rsyslog
apt dist-upgrade -y

temp_packages="git make gcc libusb-1.0-0-dev librtlsdr-dev libncurses5-dev zlib1g-dev python3-dev python3-venv"
packages="chrony librtlsdr0 lighttpd zlib1g dump978-fa soapysdr-module-rtlsdr socat netcat uuid-runtime"
packages+=" dnsutils jq" # for adsbexchange-stats, avoid invoking apt install gain

apt install --no-install-recommends --no-install-suggests -y $packages $temp_packages

apt purge -y piaware-repository
rm -f /etc/apt/sources.list.d/piaware-*.list

bash /adsbexchange/update/update-adsbx.sh

git clone --depth 1 https://github.com/dstreufert/adsbx-webconfig.git
cd adsbx-webconfig
bash install.sh

bash -c "$(curl -L -o - https://github.com/wiedehopf/graphs1090/raw/master/install.sh)"

apt remove -y $temp_packages
apt autoremove -y
apt clean

# delete var cache
#rm -rf /var/cache/*
# Regenerate man database.
#/usr/bin/mandb

# config symlinks
ln -sf /boot/adsbx-978env /etc/default/dump978-fa
ln -sf /boot/adsbx-env /etc/default/readsb
ln -sf /boot/adsb-config.txt /etc/default/adsbexchange
