#!/bin/bash

set -x

VXLAN_OVERHEAD=50
IPSEC_OVERHEAD=56

eth0_mtu=$(cat /sys/class/net/eth0/mtu)

sysctl -w net.ipv4.ip_forward=1
sysctl -w net.ipv4.conf.all.rp_filter=0

if [[ "$IPSEC_SIDE" == "left" ]]; then
   local_overlay_ip=$LEFT_OVERLAY_IP
   echo $LEFT_OVERLAY_IP $RIGHT_OVERLAY_IP : PSK \"$PSK\" > /etc/ipsec.secrets
   srcport1=$((VXLAN_PORT + 30))
   srcport2=$((VXLAN_PORT + 40))
else
   local_overlay_ip=$RIGHT_OVERLAY_IP
   echo $RIGHT_OVERLAY_IP $LEFT_OVERLAY_IP : PSK \"$PSK\" > /etc/ipsec.secrets
   srcport1=$((VXLAN_PORT + 10))
   srcport2=$((VXLAN_PORT + 20))
fi

# SETUP VXLAN TUNNEL


ip link add name vxlan42 type vxlan id 42 remote $REMOTE_IP dstport $VXLAN_PORT srcport $srcport1 $srcport2
ip link set dev vxlan42 mtu $((eth0_mtu - VXLAN_OVERHEAD))
ip addr add $local_overlay_ip/24 dev vxlan42
ip link set up vxlan42

ethtool -K eth0 tx-checksum-ip-generic off

# WRITE IPSEC CONFIG

cat <<EOF > /etc/ipsec.conf
config setup
        virtual_private=%v4:10.0.0.0/8,%v4:192.168.0.0/16,%v4:172.16.0.0/12,%v4:25.0.0.0/8,%v4:100.64.0.0/10,%v6:fd00::/8,%v6:fe80::/10
        protostack=netkey

conn mytunnel
    auto=add
    nat-ikev1-method=none
    authby=secret
    left=$LEFT_OVERLAY_IP
    right=$RIGHT_OVERLAY_IP
    leftsubnet=0.0.0.0/0
    rightsubnet=0.0.0.0/0
    mark=5/0xffffffff
    vti-interface=vti01
    vti-routing=no
    mtu=$((eth0_mtu - VXLAN_OVERHEAD - IPSEC_OVERHEAD))
EOF


# Check configuration file
/usr/libexec/ipsec/addconn --config /etc/ipsec.conf --checkconfig
# Check for kernel modules
/usr/libexec/ipsec/_stackmanager start
# Check for nss database status and migration
/usr/sbin/ipsec --checknss
# Check for nflog setup
/usr/sbin/ipsec --checknflog
# Start the actual IKE daemon
/usr/libexec/ipsec/pluto --leak-detective --config /etc/ipsec.conf #--nofork
sleep 5
ipsec auto --add mytunnel
