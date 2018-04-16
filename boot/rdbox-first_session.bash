#!/bin/bash

regex_master='^.*master.*'
regex_slave='^.*slave.*'
hname=`/bin/hostname`

/usr/bin/lsusb -t | /bin/grep -B 1 rt2800usb | /bin/grep -o "Port [0-9]*" | /bin/grep -o "[0-9]*" | /usr/bin/python /opt/rdbox/boot/rdbox-bind_unbind_dongles.py

if [[ $hname =~ $regex_master ]]; then
  mv /etc/network/interfaces /etc/network/interfaces.org
  cp -rf /etc/rdbox/networks/interface/master /etc/network/interfaces
  /etc/init.d/networking restart
  /bin/systemctl enable rdbox-boot.service
  /bin/systemctl restart rdbox-boot.service
elif [[ $hname =~ $regex_slave ]]; then
  mv /etc/network/interfaces /etc/network/interfaces.org
  cp -rf /etc/rdbox/networks/interface/slave /etc/network/interfaces
  /etc/init.d/networking restart
  /bin/systemctl enable rdbox-boot.service
  /bin/systemctl restart rdbox-boot.service
else
  cp -rf /etc/rdbox/networks/interface/wlan0 /etc/network/interfaces.d/wlan0
  /etc/init.d/networking restart
fi

exit 0
