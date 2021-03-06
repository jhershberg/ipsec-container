#!/bin/sh
set -x

# Input parameters

PSK=${PSK:-uazioghXBFsKmOEy9tMKjGE9G3o61iGpEmquNf28xt4inDVIume1fkyEZk2B79rG}
IPSEC_SIDE=${IPSEC_SIDE:-left}
VXLAN_PORT=${VXLAN_PORT:-4789}
REMOTE_IP=${REMOTE_IP:-NOIP}

# Optional parameter tweaks

LEFT_OVERLAY_IP=${LEFT_OVERLAY_IP:-169.254.0.1}
RIGHT_OVERLAY_IP=${RIGHT_OVERLAY_IP:-169.254.0.2}


if [[ "$REMOTE_IP" == "NOIP" ]]; then

   echo error: please, specify a REMOTE_IP env variable
   exit 1 
fi

source /setup.sh

if [[ "$IPSEC_SIDE" == "left" ]]; then 
	ipsec auto --up mytunnel
	sleep 5
fi

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
    if [[ "$IPSEC_SIDE" == "left" ]]; then
       ipsec whack --trafficstatus | grep -q '"mytunnel"' || echo "TUNNEL DISCONNECTED"
    fi
    sleep 5
done
