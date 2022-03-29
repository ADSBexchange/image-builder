# image-builder

## Building the adsbexchange image based on buster:

```
git clone https://github.com/ADSBexchange/image-builder.git
cd image-builder
wget https://downloads.raspberrypi.org/raspios_oldstable_lite_armhf/images/raspios_oldstable_lite_armhf-2021-12-02/2021-12-02-raspios-buster-armhf-lite.zip
unzip 2021-12-02-raspios-buster-armhf-lite.zip
 ./create-image.sh 2021-12-02-raspios-buster-armhf-lite.img buster.img
```

## Building the adsbexchange image base on bullseye

Should work similar as above, not yet tested
```
https://downloads.raspberrypi.org/raspios_lite_armhf/images/raspios_lite_armhf-2022-01-28/2022-01-28-raspios-bullseye-armhf-lite.zip
```

## tracking down disk writes

```
stdbuf -oL -eL inotifywait -r -m /etc /adsbexchange /opt /root /home /usr /lib /boot /var 2>&1 | stdbuf -oL grep -v -e OPEN -e NOWRITE -e ACCESS -e /var/tmp -e /var/cache/fontconfig -e /var/lib/systemd/timers -e /var/log | ts >> /tmp/inot
```
