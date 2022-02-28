#!/bin/bash
if [[ "$MLAT_MARKER" == "no" ]]; then
    PRIVACY="--privacy"
fi
exec /usr/local/share/adsbexchange/venv/bin/mlat-client \
    --input-type $INPUT_TYPE --no-udp \
    --input-connect $INPUT \
    $PRIVACY \
    --server $MLATSERVER \
    --user $USER \
    --lat $LATITUDE \
    --lon $LONGITUDE \
    --alt $ALTITUDE \
    $RESULTS
