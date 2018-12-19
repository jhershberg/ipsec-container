Scripts that build and launch a docker container that
connects to an AWS VPN.

Usage:

A number (~60) kernel modules are required on the host. The easiest way to install
these is by installing libreswan and then starting and stopping it:

```ipsec setup start && ipsec setup stop```

1. See the vars file for the variables that need to be set
2. to build, say ./build

You can test the containers by running:

```bash
sudo docker run --rm -ti  -e PSK=<redacted> -e LEFT_IP=192.168.0.6 -e RIGHT_IP=13.58.178.57 --privileged tun
```
