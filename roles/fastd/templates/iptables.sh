#!/bin/sh
/sbin/ip route add default via {{ external_ipv4 }} table 42
/sbin/ip route add 10.144.0.0/16 dev br-ffsh src {{ ffsh_ipv4_address }} table 42
/sbin/ip route add 0/1 dev tun0 table 42
/sbin/ip route add 128/1 dev tun0 table 42
/sbin/ip route del default via {{ external_ipv4 }} table 42
/sbin/iptables -t nat -D POSTROUTING -s 0/0 -d 0/0 -j MASQUERADE > /dev/null 2>&1
/sbin/iptables -t nat -I POSTROUTING -s 0/0 -d 0/0 -j MASQUERADE
/sbin/iptables -t nat -D POSTROUTING -s 0/0 -d 0/0 -o tun0 -j MASQUERADE > /dev/null 2>&1
/sbin/iptables -t mangle -D PREROUTING -s 10.144.96.0/20 -j MARK --set-mark 0x1 > /dev/null 2>&1
/sbin/iptables -t mangle -I PREROUTING -s 10.144.96.0/20 -j MARK --set-mark 0x1
/sbin/iptables -t mangle -D OUTPUT -s 10.144.96.0/20 -j MARK --set-mark 0x1 > /dev/null 2>&1
/sbin/iptables -t mangle -I OUTPUT -s 10.144.96.0/20 -j MARK --set-mark 0x1
# IGMP/MLD segmentation
echo 2 > /sys/class/net/bat0/brport/multicast_router