#!/bin/sh

if [ "$(ls /etc/wireguard/*.conf 2>/dev/null | wc -l)" == "0" ]; then
  echo "---No WireGuard .conf file found!---"
  kill -s SIGTERM 1
  sleep infinity
else
  WG_CONF_FILE=$(ls /etc/wireguard/*.conf 2>/dev/null | sort -V | head -1)
  echo "---WireGuard config file found: ${WG_CONF_FILE}---"
  if [ "${WG_CONF_FILE}" != "/etc/wireguard/wg0.conf" ]; then
    mv "${WG_CONF_FILE}" "/etc/wireguard/wg0.conf"
  fi
fi

echo "---Starting WireGuard tunnel---"
wg-quick up wg0 > /dev/null 2>&1
EXIT_STATUS=$?

if [ ${EXIT_STATUS} != 0 ]; then
  echo "---Can't start WireGuard tunnel, please check your config!---"
else
  echo "---WireGuard tunnel started successfully...---"
  if ! grep -q "::/0" /etc/wireguard/wg0.conf; then
        ip6tables -P OUTPUT DROP
        echo "Public IP: $(wget -qO- ipv4.icanhazip.com)"
  elif ! grep -q "0.0.0.0/0" /etc/wireguard/wg0.conf; then
        iptables -P OUTPUT DROP
        echo "Public IP: $(wget -qO- ipv6.icanhazip.com)"
  else
        echo "Public IP: $(wget -qO- -T 3 ipv4.icanhazip.com) $(wget -qO- -T 3 ipv6.icanhazip.com)"
  fi
  if [ ! -z ${LAN_NETWORK} ]; then
  ip route add $LAN_NETWORK via 172.17.0.1 dev eth0
  fi
  if [ ! -z ${LAN_NETWORK6} ]; then
  ip -6 route add $LAN_NETWORK6 via fd17::1 dev eth0
  fi
  ./microsocks -q -i 0.0.0.0 -p 1080 &
  privoxy /etc/privoxy/config
fi

while true
do
status=$(wg)
if [[ -z "$status" ]]; then
   kill -s SIGTERM 1
   sleep infinity
   break
else
   sleep 1
fi
done
