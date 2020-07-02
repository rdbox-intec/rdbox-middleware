#!/bin/bash

if [ "$(whoami)" != "root" ]; then
  echo "Require root privilege"
  exit 1
fi

if unlink /opt/rdbox;
then
  mv /opt/.original.rdbox /opt/rdbox
  unlink /etc/rdbox/network/iptables
  mv /etc/rdbox/network/.original.iptables /etc/rdbox/network/iptables
  unlink /etc/rdbox/network/iptables.mstsimple.eth0
  mv /etc/rdbox/network/.original.iptables.mstsimple.eth0 /etc/rdbox/network/iptables.mstsimple.eth0
  unlink /etc/rdbox/network/iptables.mstsimple.wlan0
  mv /etc/rdbox/network/.original.iptables.mstsimple.wlan0 /etc/rdbox/network/iptables.mstsimple.wlan0
fi

echo "SUCCESS"