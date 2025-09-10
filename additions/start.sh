#!/bin/sh
echo "---Starting...---"
#healthcheck
if [ -e /tmp/failure ]; then
    rm /tmp/failure
fi
term_handler() {
  echo "---Stopping WireGuard tunnel---"
  wg-quick down wg0 > /dev/null 2>&1
  kill $(pidof sleep)
  exit 143;
}

if [ ! -z "${CONNECTED_CONTAINERS}" ]; then
  /start-connected-containers.sh &
fi

trap 'kill ${!}; term_handler' SIGTERM
/start-wg.sh &
killpid="$!"
while true
do
	wait $killpid
	exit 0;
done
