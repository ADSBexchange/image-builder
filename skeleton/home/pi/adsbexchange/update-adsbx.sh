#!/bin/bash
set -e

if [[ "$(id -u)" != "0" ]]; then
    exec sudo bash "$BASH_SOURCE"
fi

# keep track of the last executed command
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
# echo an error message before exiting
trap 'echo "\"${last_command}\" command filed with exit code $?."' EXIT


restartIfEnabled() {
    if systemctl is-enabled "$1" &>/dev/null; then
	    systemctl restart "$1"
    fi
}

echo '########################################'
echo 'FULL LOG ........'
echo 'located at /tmp/adsbx_update_log .......'
echo '########################################'
echo '..'
echo 'cloning to decoder /tmp .......'
cd /tmp
rm -f -R /tmp/readsb
git clone --quiet --depth 1 https://github.com/adsbxchange/readsb.git > /tmp/adsbx_update_log

echo 'compiling readsb (this can take a while) .......'
cd readsb
#make -j3 AIRCRAFT_HASH_BITS=12 RTLSDR=yes
make -j3 AIRCRAFT_HASH_BITS=12 RTLSDR=yes OPTIMIZE="-mcpu=arm1176jzf-s -mfpu=vfp"  >> /tmp/adsbx_update_log


echo 'copying new readsb binaries ......'
cp -f readsb /usr/bin/adsbxfeeder
cp -f readsb /usr/bin/adsbx-978
cp -f readsb /usr/bin/readsb
cp -f viewadsb /usr/bin/viewadsb

echo 'restarting services .......'
restartIfEnabled readsb
restartIfEnabled adsbexchange-feed
restartIfEnabled adsbexchange-978

echo 'cleaning up decoder .......'
cd /tmp
rm -f -R /tmp/readsb

echo 'updating adsbx stats .......'
wget --quiet -O /tmp/axstats.sh https://raw.githubusercontent.com/adsbxchange/adsbexchange-stats/master/stats.sh >> /tmp/adsbx_update_log
{ bash /tmp/axstats.sh; } >> /tmp/adsbx_update_log 2>&1

echo 'cleaming up stats /tmp .......'
rm -f /tmp/axstats.sh
rm -f -R /tmp/adsbexchange-stats-git

echo 'cloning to python virtual environment for mlat-client .......'
VENV=/usr/local/share/adsbexchange/venv/
if [[ -f /usr/local/share/adsbexchange/venv/bin/python3.7 ]] && command -v python3.9 &>/dev/null;
then
    rm -rf "$VENV"
fi
apt install -y python3-venv >> /tmp/adsbx_update_log
/usr/bin/python3 -m venv "$VENV"

echo 'stopping mlat services .......'
systemctl stop adsbexchange-mlat.service

echo 'cloning to mlat-client /tmp .......'
cd /tmp
rm -f -R /tmp/mlat-client
git clone --quiet --depth 1 --single-branch https://github.com/adsbxchange/mlat-client.git >> /tmp/adsbx_update_log

echo 'building and installing mlat-client to virtual-environment .......'
cd mlat-client
source /usr/local/share/adsbexchange/venv/bin/activate >> /tmp/adsbx_update_log
python3 setup.py build >> /tmp/adsbx_update_log
python3 setup.py install >> /tmp/adsbx_update_log

echo 'starting services .......'
restartIfEnabled adsbexchange-mlat

echo 'cleaning up mlat-client .......'
cd /tmp
rm -f -R /tmp/mlat-client
rm -f /usr/local/share/adsbexchange/venv/bin/fa-mlat-client

echo 'update uat ...'

cd /tmp
rm -f -R /tmp/uat2esnt
git clone https://github.com/adsbxchange/uat2esnt.git >> /tmp/adsbx_update_log
cd uat2esnt
make  >> /tmp/adsbx_update_log
cp -f uat2esnt /usr/local/share/uat2esnt
cd /tmp
rm -f -R /tmp/uat2esnt

echo 'restart uat services .......'
restartIfEnabled adsbexchange-978-convert

echo 'update tar1090 ...........'
bash -c "$(wget -nv -O - https://raw.githubusercontent.com/wiedehopf/tar1090/master/install.sh)"  >> /tmp/adsbx_update_log

echo "#####################################"
cat /boot/adsbx-uuid
echo "#####################################"
sed -e 's$^$https://www.adsbexchange.com/api/feeders/?feed=$' /boot/adsbx-uuid
echo "#####################################"

echo '--------------------------------------------'
echo '--------------------------------------------'
echo '             UPDATE COMPLETE'
echo '      FULL LOG:  /tmp/adsbx_update_log'
echo '--------------------------------------------'
echo '--------------------------------------------'
exit 0

