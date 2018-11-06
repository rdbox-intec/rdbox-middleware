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
  ln -s /etc/rdbox/network/interfaces /etc/network/interfaces
  cp -n /etc/rdbox/network/interfaces.d/master/* /etc/rdbox/network/interfaces.d/current
  /etc/init.d/networking restart
  /bin/systemctl enable rdbox-boot.service
  /bin/systemctl restart rdbox-boot.service
  /bin/systemctl enable dnsmasq.service
  /bin/systemctl restart dnsmasq.service
  mkdir -p /usr/local/share/rdbox
  echo "/usr/local/share/rdbox 192.168.179.0/24(rw,sync,no_subtree_check,no_root_squash,no_all_squash)" >> /etc/exports
  /bin/systemctl enable nfs-kernel-server.service
  /bin/systemctl start nfs-kernel-server.service
  sed -i '/^#ListenAddress 0.0.0.0$/c ListenAddress 192.168.179.1' /etc/ssh/sshd_config
  /etc/init.d/ssh restart
  http_proxy_size=`wc -c /etc/transproxy/http_proxy | awk '{print $1}'`
  no_proxy_size=`wc -c /etc/transproxy/no_proxy | awk '{print $1}'`
  if [ $http_proxy_size -gt 5 ] && [ $no_proxy_size -gt 5 ]; then
    /bin/systemctl enable transproxy.service
    /bin/systemctl restart transproxy.service
  else
    /bin/systemctl disable transproxy.service
    /bin/systemctl stop transproxy.service
  fi
elif [[ $hname =~ $regex_slave ]]; then
  /usr/bin/lsusb -t | /bin/grep -B 1 rt2800usb | /bin/grep -o "Port [0-9]*" | /bin/grep -o "[0-9]*" | /usr/bin/python /opt/rdbox/boot/rdbox-bind_unbind_dongles.py
  mv /etc/network/interfaces /etc/network/interfaces.org
  ln -s /etc/rdbox/network/interfaces /etc/network/interfaces
  cp -n /etc/rdbox/network/interfaces.d/slave/* /etc/rdbox/network/interfaces.d/current
  /sbin/ifconfig wlan0 | grep -o -E '([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}' > /etc/rdbox/hostapd_be.deny
  /etc/init.d/networking restart
  /sbin/dhclient br0
  /bin/systemctl enable rdbox-boot.service
  /bin/systemctl restart rdbox-boot.service
  /bin/systemctl disable systemd-networkd-wait-online.service
  /bin/systemctl mask systemd-networkd-wait-online.service
  sed -i '/^#timeout 60;$/c timeout 10;' /etc/dhcp/dhclient.conf
elif [[ $hname =~ $regex_vpnbridge ]]; then
  mv /etc/network/interfaces /etc/network/interfaces.org
  ln -s /etc/rdbox/network/interfaces /etc/network/interfaces
  cp -n /etc/rdbox/network/interfaces.d/vpnbridge/* /etc/rdbox/network/interfaces.d/current
  ln -s /etc/rdbox/wpa_supplicant_ap_bg.conf /etc/wpa_supplicant/wpa_supplicant.conf
  /etc/init.d/networking restart
  /sbin/ifup wlan10
  /sbin/dhclient wlan10 
  /sbin/ip addr del `ip -f inet -o addr show eth0|cut -d\  -f 7 | cut -d/ -f 1`/24 dev eth0
  /bin/systemctl enable softether-vpnbridge.service
  /bin/systemctl restart softether-vpnbridge.service
  sleep 30
  /usr/bin/vpncmd localhost:443 -server -in:/usr/local/etc/vpnbridge.in
  /bin/systemctl restart softether-vpnbridge.service
else
  mv /etc/network/interfaces /etc/network/interfaces.org
  ln -s /etc/rdbox/network/interfaces /etc/network/interfaces
  cp -n /etc/rdbox/network/interfaces.d/others/* /etc/rdbox/network/interfaces.d/current
  ln -s /etc/rdbox/wpa_supplicant_ap_bg.conf /etc/wpa_supplicant/wpa_supplicant.conf
  /etc/init.d/networking restart
  /sbin/ifup wlan10
  /sbin/dhclient wlan10 
fi

exit 0
