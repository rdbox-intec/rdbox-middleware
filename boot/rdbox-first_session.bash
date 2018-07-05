#!/bin/bash

regex_master='^.*master.*'
regex_slave='^.*slave.*'
regex_vpnbridge='^.*vpnbridge.*'
hname=`/bin/hostname`

# Pickup the hostname changes
/bin/systemctl restart avahi-daemon

if [[ $hname =~ $regex_master ]]; then
  /usr/bin/lsusb -t | /bin/grep -B 1 rt2800usb | /bin/grep -o "Port [0-9]*" | /bin/grep -o "[0-9]*" | /usr/bin/python /opt/rdbox/boot/rdbox-bind_unbind_dongles.py
  mv /etc/network/interfaces /etc/network/interfaces.org
  cp -rf /etc/rdbox/templates/interface/master /etc/network/interfaces
  /etc/init.d/networking restart
  /bin/systemctl enable rdbox-boot.service
  /bin/systemctl restart rdbox-boot.service
  /bin/systemctl enable dnsmasq.service
  /bin/systemctl restart dnsmasq.service
elif [[ $hname =~ $regex_slave ]]; then
  /usr/bin/lsusb -t | /bin/grep -B 1 rt2800usb | /bin/grep -o "Port [0-9]*" | /bin/grep -o "[0-9]*" | /usr/bin/python /opt/rdbox/boot/rdbox-bind_unbind_dongles.py
  mv /etc/network/interfaces /etc/network/interfaces.org
  cp -rf /etc/rdbox/templates/interface/slave /etc/network/interfaces
  /etc/init.d/networking restart
  /bin/systemctl enable rdbox-boot.service
  /bin/systemctl restart rdbox-boot.service
  /bin/systemctl disable systemd-networkd-wait-online.service
  /bin/systemctl mask systemd-networkd-wait-online.service
  sed -i '/^#timeout 60;$/c timeout 10;' /etc/dhcp/dhclient.conf
elif [[ $hname =~ $regex_vpnbridge ]]; then
  mv /etc/network/interfaces /etc/network/interfaces.org
  cp -rf /etc/rdbox/templates/interface/vpnbridge /etc/network/interfaces
  ln -s /etc/rdbox/wpa_supplicant_ap_bg.conf /etc/wpa_supplicant/wpa_supplicant.conf
  /etc/init.d/networking restart
  /sbin/ifup wlan10
  /sbin/ip addr del `ip -f inet -o addr show eth0|cut -d\  -f 7 | cut -d/ -f 1`/24 dev eth0
  /bin/systemctl enable softether-vpnbridge.service
  /bin/systemctl restart softether-vpnbridge.service
  sleep 30
  /usr/bin/vpncmd localhost:443 -server -in:/usr/local/etc/vpnbridge.in
  /bin/systemctl restart softether-vpnbridge.service
else
  cp -rf /etc/rdbox/templates/interface/wlan10 /etc/network/interfaces.d/wlan10
  ln -s /etc/rdbox/wpa_supplicant_ap_bg.conf /etc/wpa_supplicant/wpa_supplicant.conf
  /etc/init.d/networking restart
  /sbin/ifup wlan10
fi

exit 0
