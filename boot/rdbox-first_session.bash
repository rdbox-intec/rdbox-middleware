#!/bin/bash

regex_master='^.*master.*'
regex_slave='^.*slave.*'
hname=`/bin/hostname`

/usr/bin/lsusb -t | /bin/grep -B 1 rt2800usb | /bin/grep -o "Port [0-9]*" | /bin/grep -o "[0-9]*" | /usr/bin/python /etc/rdbox/boot/rdbox-bind_unbind_dongles.py

mv /etc/network/interfaces /etc/network/interfaces.org

if [[ $hname =~ $regex_master ]]; then
  cp -rf /etc/rdbox/networks/interface/master /etc/network/interfaces
  /etc/init.d/networking restart
elif [[ $hname =~ $regex_slave ]]; then
  cp -rf /etc/rdbox/networks/interface/slave /etc/network/interfaces
  /etc/init.d/networking restart
fi

/bin/systemctl enable rdbox-boot.service
/bin/systemctl restart  rdbox-boot.service

exit 0
