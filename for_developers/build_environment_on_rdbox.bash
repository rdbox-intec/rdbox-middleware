#!/bin/bash

if [ "$(whoami)" != "root" ]; then
  echo "Require root privilege"
  exit 1
fi

if [ ! -L /opt/rdbox ]; then
  mv /opt/rdbox /opt/.original.rdbox
  ln -s /home/"${SUDO_USER}"/rdbox-middleware /opt/rdbox
  mv /etc/rdbox/network/iptables /etc/rdbox/network/.original.iptables
  ln -s /home/"${SUDO_USER}"/rdbox-middleware/templates/networks/iptables/iptables /etc/rdbox/network/iptables
  mv /etc/rdbox/network/iptables.mstsimple.eth0 /etc/rdbox/network/.original.iptables.mstsimple.eth0
  ln -s /home/"${SUDO_USER}"/rdbox-middleware/templates/networks/iptables/iptables.mstsimple.eth0 /etc/rdbox/network/iptables.mstsimple.eth0
  mv /etc/rdbox/network/iptables.mstsimple.wlan0 /etc/rdbox/network/.original.iptables.mstsimple.wlan0
  ln -s /home/"${SUDO_USER}"/rdbox-middleware/templates/networks/iptables/iptables.mstsimple.wlan0 /etc/rdbox/network/iptables.mstsimple.wlan0
else
  echo "It's already set up."
fi

echo "SUCCESS"