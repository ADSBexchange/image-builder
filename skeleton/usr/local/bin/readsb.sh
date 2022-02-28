#!/bin/bash

if [[ "$DUMP1090" == "no" ]]; then
    RECEIVER_OPTIONS="--net-only"
fi

exec /usr/bin/readsb --gain $GAIN --lat $LATITUDE --lon $LONGITUDE \
 $RECEIVER_OPTIONS $DECODER_OPTIONS --db-file=none $NET_OPTIONS $JSON_OPTIONS \
 --write-json /run/readsb --quiet
