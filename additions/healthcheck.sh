HEALTHCHECK_FILE="/tmp/failure"
if [ ! -f "$HEALTHCHECK_FILE" ]; then
    echo 0 > "$HEALTHCHECK_FILE"
fi

FAILURE_COUNT=$(cat "$HEALTHCHECK_FILE")

if [ ! -z ${HEALTH_URL_CHECK} ]; then
HOST=$HEALTH_URL_CHECK
else
if [ -z ${DISABLE_TUNNEL_MODE} ]; then
PEER=$(grep -i "^Endpoint" "/etc/wireguard/wg0.conf" | head -n1 | cut -d'=' -f2 | tr -d ' ')
HOST1=$(echo "$PEER" | rev | cut -d':' -f2- | rev)
HOST2=$(echo "$HOST1" | sed 's/^\[//;s/\]$//')
HOST=$(traceroute -m 1 -w 1 -n -i wg0 "$HOST2" | awk 'NR==2 {print $2}')
if [ "$HOST" = "*" ]; then
    HOST="$HOST2"
fi
else
PEER=$(grep -i "^AllowedIP" "/etc/wireguard/wg0.conf" | head -n1 | cut -d'=' -f2 | tr -d ' ' | awk -F',' '{print $1}' | awk -F'/' '{print $1}')
HOST=$(traceroute -m 1 -w 1 -n -i wg0 "$PEER" | awk 'NR==2 {print $2}')
fi
fi

ping -I wg0 -c 1 -W 20 "$HOST" > /dev/null 2>&1
if [ $? -eq 0 ]; then
    if [ "$(cat "$HEALTHCHECK_FILE")" != "0" ]; then
      echo "0" > "$HEALTHCHECK_FILE"
    fi
    exit 0
else
    FAILURE_COUNT=$((FAILURE_COUNT + 1))
    echo "$FAILURE_COUNT" > "$HEALTHCHECK_FILE"

    if [ "$FAILURE_COUNT" -ge 6 ]; then
        wg-quick down wg0 && wg-quick up wg0 > /dev/null 2>&1
        echo 0 > "$HEALTHCHECK_FILE"
    fi
    exit 1
fi