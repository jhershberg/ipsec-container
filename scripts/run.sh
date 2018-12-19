#!/bin/sh
set -x

# Input parameters

PSK=${PSK:-uazioghXBFsKmOEy9tMKjGE9G3o61iGpEmquNf28xt4inDVIume1fkyEZk2B79rG}

# Optional parameter tweaks

LEFT_IP=${LEFT_IP:-169.254.0.1}
RIGHT_IP=${RIGHT_IP:-169.254.0.2}

source /setup.sh

ipsec auto --up tunnel1
sleep 5

# post connection

while true
do
    ip tunnel | grep -q vti01 && break
    sleep 1
done

if [ -f /configuration/routes.sh ]
then
    /configuration/routes.sh
fi

# SRC_VXLAN_PORT=$(tcpdump -i eth0 -nn port 4789 -c 1 -Q in 2>/dev/null | head -n 1 | cut -d\  -f 3 | cut -d. -f 5)

while true
do
    ipsec whack --trafficstatus | grep -q '"tunnel1"' || echo "TUNNEL DISCONNECTED"
    sleep 5
done
