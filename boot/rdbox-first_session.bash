#!/bin/bash

regex_master='^.*master.*'
regex_slave='^.*slave.*'
hname=`/bin/hostname`

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
  sed -i '/^#timeout 60;$/c timeout 15;' /etc/dhcp/dhclient.conf
else
  cp -rf /etc/rdbox/templates/interface/wlan10 /etc/network/interfaces.d/wlan10
  ln -s /etc/rdbox/wpa_supplicant_ap_bg.conf /etc/wpa_supplicant/wpa_supplicant.conf
  /etc/init.d/networking restart
  /sbin/ifup wlan10 &
  /sbin/ifup eth0 &
fi

exit 0
