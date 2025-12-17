#!/bin/sh

if [ "$(ls /etc/wireguard/*.conf 2>/dev/null | wc -l)" == "0" ]; then
  echo "---No WireGuard .conf file found!---"
  kill -15 1 > /dev/null 2>&1
  sleep infinity
else
  if [ "${ENABLE_RANDOM}" == "1" ]; then
    WG_CONF_FILE=$(ls /etc/wireguard/*.conf 2>/dev/null | grep -v "/etc/wireguard/wg0.conf" | shuf -n 1)
    echo "---Random WireGuard config file selected: ${WG_CONF_FILE}---"
  else
    WG_CONF_FILE=$(ls /etc/wireguard/*.conf 2>/dev/null | sort -V | head -1)
    echo "---WireGuard config file found: ${WG_CONF_FILE}---"
  fi
  if [ "${WG_CONF_FILE}" != "/etc/wireguard/wg0.conf" ]; then
    cp "${WG_CONF_FILE}" "/etc/wireguard/wg0.conf"
  fi
fi

#Openresolv shenanigans
cat /etc/resolv.conf | resolvconf -a control > /dev/null 2>&1
resolvconf -u > /dev/null 2>&1

#Grab Gateway before removing it
IP4GATEWAY=$(ip route | awk '/default/ { print $3 }')
IP6GATEWAY=$(ip -6 route | awk '/default/ { print $3 }')


iptables -I OUTPUT -d 192.168.0.0/16 -j ACCEPT
iptables -I OUTPUT -d 172.16.0.0/12 -j ACCEPT
iptables -I OUTPUT -d 10.0.0.0/8 -j ACCEPT
ip6tables -I OUTPUT -d fc00::/7 -j ACCEPT


if [ -z ${DISABLE_TUNNEL_MODE} ]; then
    if ! grep -q "::/0" /etc/wireguard/wg0.conf; then
        ip -6 route flush default
    fi
    if ! grep -q "0.0.0.0/0" /etc/wireguard/wg0.conf; then
        ip route flush default
    fi
fi

echo "---Starting WireGuard tunnel---"
#Userspace fallback
mkdir -p /dev/net
mknod /dev/net/tun c 10 200
chmod 600 /dev/net/tun
sleep 1
#---------
wg-quick up wg0 > /dev/null 2>&1
EXIT_STATUS=$?

if [ ${EXIT_STATUS} != 0 ]; then
  echo "---Can't start WireGuard tunnel, please check your config!---"
  kill -15 1 > /dev/null 2>&1
else
  echo "---WireGuard tunnel started successfully...---"
    if [ -z ${DISABLE_TUNNEL_MODE} ]; then
    FWMARK=$(wg show wg0 fwmark)
    iptables -A OUTPUT ! -o wg0 -m mark ! --mark "$FWMARK" -m addrtype ! --dst-type LOCAL -j REJECT
    ip6tables -A OUTPUT ! -o wg0 -m mark ! --mark "$FWMARK" -m addrtype ! --dst-type LOCAL -j REJECT
    fi
    PUBLIC_IP4=$(wget -qO- -T 3 ipv4.icanhazip.com > /dev/null 2>&1)
    if [ $? -eq 0 ]; then
        echo "Public IPv4: $(wget -qO- -T 3 ipv4.icanhazip.com)"
    fi
    PUBLIC_IP6=$(wget -qO- -T 3 ipv6.icanhazip.com > /dev/null 2>&1)
    if [ $? -eq 0 ]; then
        echo "Public IPv6: $(wget -qO- -T 3 ipv6.icanhazip.com)"
    fi
  if [ ! -z ${LAN_NETWORK} ] && [ ! -z ${IP4GATEWAY} ]; then
    IFS=',' 
    set -- ${LAN_NETWORK}
    for network in "$@"; do
      network=$(echo "$network" | xargs)
      ip route add "${network}" via $IP4GATEWAY dev eth0 onlink
    done
  fi
  if [ ! -z ${LAN_NETWORK6} ]  && [ ! -z ${IP6GATEWAY} ]; then
    IFS=',' 
    set -- ${LAN_NETWORK6}
    for network6 in "$@"; do
      network6=$(echo "$network6" | xargs)
      ip -6 route add "${network6}" via $IP6GATEWAY dev eth0 onlink
    done  
  fi
  ./microsocks -q -i :: -p 1080 &
  sed -i "s|listen-address \[::\]:.*|listen-address [::]:${HTTPPORT}|" /etc/privoxy/config
  privoxy /etc/privoxy/config
fi

sleep infinity
