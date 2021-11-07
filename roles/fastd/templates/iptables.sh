#!/bin/sh

/sbin/ip route add 10.144.0.0/16 dev bat0 src {{ ffsh_ipv4_address }} table 42

# Reject forwarded outgoing packets on external WAN interface to private IP addresses
/sbin/iptables -I FORWARD -d 10.0.0.0/8 -o {{ external_interface }} -j REJECT
/sbin/iptables -I FORWARD -d 172.16.0.0/12 -o {{ external_interface }} -j REJECT
/sbin/iptables -I FORWARD -d 192.168.0.0/16 -o {{ external_interface }} -j REJECT
/sbin/iptables -I FORWARD -d 100.64.0.0/10 -o {{ external_interface }} -j REJECT
/sbin/iptables -I FORWARD -d 169.254.0.0/16 -o {{ external_interface }} -j REJECT

# this is not relevant when the gateway uses a direct exit but important when table 42 has a special interface as exit
/sbin/iptables -t mangle -I PREROUTING -s 10.144.0.0/16 -j MARK --set-mark 0x1

# nat, exit ip will be based on the route
/sbin/iptables -t nat -I POSTROUTING -s 10.144.0.0/16 -d 0/0 -j MASQUERADE
# IGMP/MLD segmentation
echo 2 > /sys/class/net/bat0/brport/multicast_router