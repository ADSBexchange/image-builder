#!/bin/sh
while wait
do
	sleep 30 &
#       if ping -q -c 2 -W 5 feed.adsbexchange.com >/dev/null 2>&1
#       then
#               echo "Connected to feed.adsbexchange.com:30005"
                /usr/bin/adsbxfeeder --quiet --net --net-only \
			--db-file=none --max-range 450 \
                        --net-beast-reduce-interval 0.5 \
			--net-connector feed.adsbexchange.com,30004,beast_reduce_out,feed.adsbexchange.com,64004 \
                        --net-connector 127.0.0.1,30005,beast_in \
                        --net-ro-interval 0.2 --net-ri-port 0 --net-ro-port 0 \
                        --net-sbs-port 0 --net-bi-port 0 --net-bo-port 0 \
                        --json-location-accuracy 2 --write-json /run/adsbexchange-feed \
			--lat $LATITUDE --lon $LONGITUDE
#               echo "Disconnected"
#       else
#               echo "Unable to connect to feed.adsbexchange.com, trying again in 30 seconds!"
#       fi
done
