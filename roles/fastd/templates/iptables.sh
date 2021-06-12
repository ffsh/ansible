#!/bin/sh

/sbin/ip route add 10.144.0.0/16 dev br-ffsh src {{ ffsh_ipv4_address }} table 42
/sbin/iptables -t nat -I POSTROUTING -s 0/0 -d 0/0 -j MASQUERADE
# IGMP/MLD segmentation
echo 2 > /sys/class/net/bat0/brport/multicast_router