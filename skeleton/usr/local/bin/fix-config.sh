#!/bin/bash

# configure fr24feed to use readsb

if grep -qs -e 'receiver.*dvb' /etc/fr24feed.ini; then
    chmod a+rw /etc/fr24feed.ini || true
    apt-get install -y dos2unix &>/dev/null && dos2unix /etc/fr24feed.ini &>/dev/null || true

    if ! grep -e 'host=' /etc/fr24feed.ini &>/dev/null; then echo 'host=' >> /etc/fr24feed.ini; fi
    if ! grep -e 'receiver=' /etc/fr24feed.ini &>/dev/null; then echo 'receiver=' >> /etc/fr24feed.ini; fi

    sed -i -e 's/receiver=.*/receiver="beast-tcp"/' -e 's/host=.*/host="127.0.0.1:30005"/' -e 's/bs=.*/bs="no"/' -e 's/raw=.*/raw="no"/' /etc/fr24feed.ini

    pkill -9 fr24feed || true
    apt purge -y dump1090 &>/dev/null
    apt purge -y dump1090-mutability &>/dev/null
    systemctl restart fr24feed &>/dev/null || true
    systemctl restart readsb &>/dev/null || true
fi

# configure rbfeeder to use readsb

if [[ -f /etc/rbfeeder.ini ]] && ! grep -qs -e '^network_mode=true' /etc/rbfeeder.ini; then
    sed -i -e '/network_mode/d' -e '/\[network\]/d' -e '/mode=/d' -e '/external_port/d' -e '/external_host/d' /etc/rbfeeder.ini
    sed -i -e 's/\[client\]/\0\nnetwork_mode=true/' /etc/rbfeeder.ini
    cat >>/etc/rbfeeder.ini <<"EOF"
[network]
mode=beast
external_port=30005
external_host=127.0.0.1
EOF
    pkill -9 rbfeeder || true
    apt purge -y dump1090 &>/dev/null
    apt purge -y dump1090-mutability &>/dev/null
    systemctl restart rbfeeder &>/dev/null || true
    systemctl restart readsb &>/dev/null || true
fi
