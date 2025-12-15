FROM alpine:latest AS builder
ARG MICROSOCKS_TAG=v1.0.5
ENV MICROSOCKS_URL="https://github.com/rofl0r/microsocks/archive/refs/tags/$MICROSOCKS_TAG.zip"
WORKDIR /build
ADD $MICROSOCKS_URL .
RUN apk add --update --no-cache \
      build-base unzip && \
      unzip $MICROSOCKS_TAG.zip && \
      cd microsocks-${MICROSOCKS_TAG:1} && \
      make && \
      cp ./microsocks ..

#Workaround for openresolv issue
FROM alpine:latest AS openresolv
RUN apk --no-cache add alpine-sdk coreutils cmake sudo bash git
COPY /build /tmp/openresolv/
WORKDIR /tmp/openresolv/
RUN mkdir -p /tmp/tmp/ && abuild-keygen -a -i -n && abuild -F checksum && abuild -F -r && find /root/packages/ -name "*.apk" -exec cp {} /tmp/tmp \;

#Userspace fallback
FROM golang:alpine AS builder2
RUN apk add --no-cache git
WORKDIR /src
RUN git clone https://github.com/WireGuard/wireguard-go
WORKDIR /src/wireguard-go
RUN go build -o /wg .
#---------

FROM alpine:latest
ENV HTTPPORT=8080
ENV CONNECTED_CONTAINERS=""
RUN apk add --no-cache iptables ip6tables wireguard-tools-wg-quick privoxy socat

#Userspace fallback
COPY --from=builder2 /wg /usr/bin/wireguard-go
#---------

RUN sed -i 's|\[\[ $proto == -4 \]\] && cmd sysctl -q net\.ipv4\.conf\.all\.src_valid_mark=1|[[ $proto == -4 ]] \&\& [[ $(sysctl -n net.ipv4.conf.all.src_valid_mark) != 1 ]] \&\& cmd sysctl -q net.ipv4.conf.all.src_valid_mark=1|' /usr/bin/wg-quick

COPY /additions /
COPY --from=builder /build/microsocks .

#Workaround for openresolv
COPY --from=openresolv /tmp/tmp/ .
RUN apk add --allow-untrusted /openresolv-3.17.3-r0.apk
RUN rm /*.apk

HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 CMD /bin/sh /healthcheck.sh
ENTRYPOINT ["/start.sh"]
