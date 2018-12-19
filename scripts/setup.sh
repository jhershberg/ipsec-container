#!/bin/bash

set -x

VXLAN_OVERHEAD=50
IPSEC_OVERHEAD=56

eth0_mtu=$(cat /sys/class/net/eth0/mtu)

sysctl -w net.ipv4.ip_forward=1
sysctl -w net.ipv4.conf.all.rp_filter=0

local_overlay_ip=$LEFT_IP
echo $LEFT_IP $RIGHT_IP : PSK \"$PSK\" > /etc/ipsec.secrets
dst_ipsec=169.254.1.2

# WRITE IPSEC CONFIG

cat <<EOF > /etc/ipsec.conf
config setup
        virtual_private=%v4:10.0.0.0/8,%v4:192.168.0.0/16,%v4:172.16.0.0/12,%v4:25.0.0.0/8,%v4:100.64.0.0/10,%v6:fd00::/8,%v6:fe80::/10
        protostack=netkey

conn tunnel1
	authby=secret
	auto=add
	left=%defaultroute
	leftid=$LEFT_IP
	right=$RIGHT_IP
	type=tunnel
	ikelifetime=8h
	keylife=1h
	phase2alg=aes128-sha1;modp1024
	ike=aes128-sha1;modp1024
	keyingtries=%forever
	keyexchange=ike
	leftsubnet=0.0.0.0/0
	rightsubnet=0.0.0.0/0
	mark=5/0xffffffff
	vti-interface=vti01
	vti-routing=no
        leftvti=169.254.1.1/30
	dpddelay=10
	dpdtimeout=30
	dpdaction=restart_by_peer
        #mtu=$((eth0_mtu - VXLAN_OVERHEAD - IPSEC_OVERHEAD)) # let's not use mtu because makes libreswan insert routes
        # This may need to be enabled since the ifc from the host is used
	#vti-sharing=yes
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
ipsec auto --add tunnel1

# redirect local port 80:490 back and forth

for proto in udp tcp; do

   iptables -t nat -A PREROUTING -p $proto -i eth0 -m multiport \
            --dports 80:490 \
            -j DNAT --to-destination $dst_ipsec
   iptables -A FORWARD -p $proto -d $dst_ipsec -m multiport \
            --dports 80:490 \
            -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT

   iptables -t nat -A POSTROUTING -j MASQUERADE
done

