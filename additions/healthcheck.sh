HEALTHCHECK_FILE="/tmp/failure"
if [ ! -f "$HEALTHCHECK_FILE" ]; then
    echo 0 > "$HEALTHCHECK_FILE"
fi

FAILURE_COUNT=$(cat "$HEALTHCHECK_FILE")


PEER=$(grep -i "^Endpoint" "/etc/wireguard/wg0.conf" | head -n1 | cut -d'=' -f2 | tr -d ' ')
HOST=$(echo "$PEER" | rev | cut -d':' -f2- | rev)
HOST=$(echo "$HOST" | sed 's/^\[//;s/\]$//')
ping -c 3 -W 20 "$HOST" > /dev/null 2>&1
if [ $? -eq 0 ]; then
    exit 0
else
    FAILURE_COUNT=$((FAILURE_COUNT + 1))
    echo "$FAILURE_COUNT" > "$HEALTHCHECK_FILE"

    if [ "$FAILURE_COUNT" -ge 12 ]; then
        wg-quick down wg0 && wg-quick up wg0 > /dev/null 2>&1
        echo 0 > "$HEALTHCHECK_FILE"
    fi
    exit 1
fi