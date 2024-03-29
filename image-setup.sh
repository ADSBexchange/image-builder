#!/bin/bash

set -e
trap 'echo "[ERROR] Error in line $LINENO when executing: $BASH_COMMAND"' ERR

export DEBIAN_FRONTEND=noninteractive

rm -rf /utemp
mkdir -p /utemp
cd /utemp

# set timezone to UTC
echo UTC > /etc/timezone
ln -s -f /usr/share/zoneinfo/UTC /etc/localtime

# fix up timezone .... not sure if there even was an issue
# anyhow this is the debian way, timedatectl and manually doing the above apparently aren't good enough for some weird debian aspects
dpkg-reconfigure --frontend noninteractive tzdata

source /etc/os-release
if (( $VERSION_ID < 11 )); then
    # only do this for old images .... not sure why we would build them
    if ! id -u pi; then
        # create pi user
        adduser pi
        adduser pi sudo
        echo "pi ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/010_pi-nopasswd
    fi
    # set password for pi user
    echo "pi:adsb123" | chpasswd
else
    # use this idiotic way to create pi user, thank you raspbian to making the above way not work
    echo -n 'pi:' > /boot/userconf.txt && echo 'adsb123' | openssl passwd -6 -stdin >> /boot/userconf.txt
fi

# for good measure, blacklist SDRs ... we don't need these kernel modules
# this isn't really necessary but it doesn't hurt
echo -e 'blacklist rtl2832\nblacklist dvb_usb_rtl28xxu\nblacklist rtl8192cu\nblacklist rtl8xxxu\n' > /etc/modprobe.d/blacklist-rtl-sdr.conf

systemctl disable dphys-swapfile.service
systemctl disable apt-daily.timer
systemctl disable apt-daily-upgrade.timer
systemctl disable man-db.timer

if ! grep -qs -e '/tmp' /etc/fstab; then
     sed -i -E -e 's/(vfat *defaults) /\1,noatime/g' /etc/fstab
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


# enable ssh
systemctl enable ssh

if grep -qs -e bullseye /etc/os-release; then
    wget -O piaware-repo.deb https://flightaware.com/adsb/piaware/files/packages/pool/piaware/p/piaware-support/piaware-repository_7.1_all.deb
elif grep -qs -e buster /etc/os-release; then
    wget -O piaware-repo.deb https://flightaware.com/adsb/piaware/files/packages/pool/piaware/p/piaware-support/piaware-repository_6.1_all.deb
elif grep -qs -e bookworm /etc/os-release; then
    wget -O piaware-repo.deb https://www.flightaware.com/adsb/piaware/files/packages/pool/piaware/f/flightaware-apt-repository/flightaware-apt-repository_1.2_all.deb
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

temp_packages="git make gcc libusb-1.0-0-dev librtlsdr-dev libncurses-dev zlib1g-dev python3-dev python3-venv libzstd-dev"
packages="chrony librtlsdr0 lighttpd zlib1g dump978-fa soapysdr-module-rtlsdr socat netcat-openbsd rtl-sdr beast-splitter libzstd1 userconf-pi"
packages+=" curl jq gzip dnsutils perl bash-builtins" # for adsbexchange-stats, avoid invoking apt install gain

# these are less than 0.5 MB each, useful tools for various stuff
packages+=" moreutils inotify-tools cpufrequtils"

while ! apt install --no-install-recommends --no-install-suggests -y $packages $temp_packages
do
    echo --------------
    echo --------------
    echo apt install failed, lets TRY AGAIN in 10 seconds!
    echo --------------
    echo --------------
    sleep 10
done

apt purge -y piaware-repository
rm -f /etc/apt/sources.list.d/piaware-*.list

mkdir -p /adsbexchange/
rm -rf /adsbexchange/update
git clone --depth 1 https://github.com/ADSBexchange/adsbx-update.git /adsbexchange/update
rm -rf /adsbexchange/update/.git

## In case of a new install and config files not present, add them.
pushd /adsbexchange/update/boot-configs &>/dev/null
for file in *; do
    if [ ! -e "/boot/$file" ]; then  # Check if the file does not exist in /boot
        echo -e "\n RESET /boot/$file"
        cp --remove-destination -f -T "$file" "/boot/$file"
    else
        echo -e "\n SKIP /boot/$file - already exists"
    fi
done
popd &>/dev/null


bash /adsbexchange/update/update-adsbx.sh

git clone --depth 1 https://github.com/ADSBexchange/adsbx-webconfig.git
pushd adsbx-webconfig
bash install.sh
popd

bash -c "$(curl -L -o - https://github.com/wiedehopf/graphs1090/raw/master/install.sh)"
#make sure the symlinks are present for graphs1090 data collection:
ln -snf /run/adsbexchange-978 /usr/share/graphs1090/978-symlink/data
ln -snf /run/readsb /usr/share/graphs1090/data-symlink/data

bash -c "$(curl -L -o - https://github.com/wiedehopf/adsb-scripts/raw/master/autogain-install.sh)"

# rsyslog / logrotate doesn't have any easy maxsize settings .... those tools can go where the sun doesn't shine
apt remove -y $temp_packages rsyslog
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
