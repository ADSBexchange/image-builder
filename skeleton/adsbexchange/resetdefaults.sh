#! /bin/bash


if [ $(id -u) -ne 0 ]; then
  echo -e "This script must be run as root. \n"
  exit 1
fi

echo -e "\n\n  APT clean"
apt-get autoremove
apt-get clean

echo -e "\n\n RESET UUID"
rm /boot/adsbx-uuid

echo -e "\n\n RESET ZT"
rm /var/lib/zerotier-one/identity.*
rm /var/lib/zerotier-one/authtoken.secret

echo -e "\n RESET SSH"
rm /etc/ssh/ssh_host_*

echo -e "\n RESET WPA_SUPPLICANT CONF"
rm /etc/wpa_supplicant/wpa_supplicant.conf
cp /home/pi/adsbexchange/.adsbx/wpa_supplicant.conf /boot/wpa_supplicant.conf

echo -e "\n RESET /boot/adsb-config.txt"
sed -i 's/\r$//' /home/pi/adsbexchange/.adsbx/adsb-config.txt
rm /boot/adsb-config.txt
cp /home/pi/adsbexchange/.adsbx/adsb-config.txt /boot/adsb-config.txt

echo -e "\n RESET /boot/adsbx-env"
sed -i 's/\r$//' /home/pi/adsbexchange/.adsbx/adsbx-env
rm /boot/adsbx-env
cp /home/pi/adsbexchange/.adsbx/adsbx-env /boot/adsbx-env

echo -e "\n RESET /boot/adsbx-978env"
sed -i 's/\r$//' /home/pi/adsbexchange/.adsbx/adsbx-978env
rm /boot/adsbx-978env
cp /home/pi/adsbexchange/.adsbx/adsbx-978env /boot/adsbx-978env

echo -e "\n REMOVE BASH HISTORY"
rm /home/pi/.bash_history


echo -e "\n RESET PI PASSWORD TO DEFAULT"
echo "pi:adsb123" | sudo chpasswd

echo -e "\n UNLOCKING UNIT UNTIL FIRST CONFIG"
touch /boot/unlock


exit 0
