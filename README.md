# WireGuard Bridge

## Quick Start

### Unraid
The template can be downloaded here
<pre>
  https://github.com/Mainfrezzer/UnRaid-Templates/blob/main/mainfrezzer-wg-bridge.xml
</pre>

### Docker run
<pre>
docker run --name wireguard-bridge\
    --restart unless-stopped \
    --cap-add=NET_ADMIN \
    --sysctl net.ipv4.conf.all.src_valid_mark=1 \
    -v /my/own/dir:/etc/wireguard/ \
    -p 1080:1080/tcp `#Socks5` \
    -p 8080:8080/tcp `#Privoxy` \
    -e LAN_NETWORK=192.168.3.0/24 `#supports multiple networks, use "," as divider` \
    -e LAN_NETWORK6=fd00::/64 `#supports multiple networks, use "," as divider` \
    -e HTTPPORT=8080 `#Privoxy Port. If you change it, dont forget to add a new port mapping` \
    -e CONNECTED_CONTAINERS= `#Optional feature of ich777 container` \
    -e ENABLE_RANDOM=0 `#Enables Random mode for the server chosen, picks a file from /etc/wireguard at random` \
    -e DISABLE_TUNNEL_MODE= `#Setting ANY value will disable the VPN tunnel enforcement.*` \
    -e HEALTH_URL_CHECK= `#Custom URL or IP to ping for the healthcheck` \
    -d ghcr.io/mainfrezzer/wg-bridge
</pre>

### Compose ###

<pre>
  wireguard-bridge:
       container_name: wireguard-bridge
       network_mode: bridge
       restart: unless-stopped
       cap_add:
           - NET_ADMIN
       sysctls:
           - net.ipv4.conf.all.src_valid_mark=1
       volumes:
           - /my/own/dir:/etc/wireguard/
       ports:
           - 1080:1080/tcp #Socks5
           - 8080:8080/tcp #Privoxy
       environment:
           - LAN_NETWORK=192.168.3.0/24 #supports multiple networks, use "," as divider
           - LAN_NETWORK6=fd00::/64 #supports multiple networks, use "," as divider
           - HTTPPORT=8080 #Privoxy Port. If you change it, dont forget to add a new port mapping
           - CONNECTED_CONTAINERS= #Optional feature of ich777 container
           - ENABLE_RANDOM=0 #Enables Random mode for the server chosen, picks a file from /etc/wireguard at random
           - DISABLE_TUNNEL_MODE= #Setting ANY value will disable the VPN tunnel enforcement.*
           - HEALTH_URL_CHECK= #Custom URL or IP to ping for the healthcheck
       image: ghcr.io/mainfrezzer/wg-bridge
</pre>

'*' That means the container will not ensure that all your traffic is routed through the VPN. This is useful if you want your containers only to reach specific VPN IPs but otherwise want to use your internet connection
