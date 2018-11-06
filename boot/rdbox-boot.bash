#!/bin/bash

regex_master='^.*master.*'
regex_slave='^.*slave.*'
regex_vpnbridge='^.*vpnbridge.*'
hname=`/bin/hostname`

if [[ $hname =~ $regex_master ]]; then
  source /etc/rdbox/network/iptables
  /bin/bash /opt/rdbox/boot/rdbox-boot_sub.bash > /var/log/rdbox_boot.log 2>&1
elif [[ $hname =~ $regex_slave ]]; then
  /bin/bash /opt/rdbox/boot/rdbox-boot_sub.bash > /var/log/rdbox_boot.log 2>&1
else
  echo "OK!!"
fi

exit 0
~      

