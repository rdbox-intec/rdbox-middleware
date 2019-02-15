#!/bin/bash

regex_master='^.*master.*'
regex_slave='^.*slave.*'
regex_vpnbridge='^.*vpnbridge.*'
hname=`/bin/hostname`

# Pickup the hostname changes
/bin/systemctl restart avahi-daemon

if [[ $hname =~ $regex_master ]]; then
  /usr/bin/lsusb -t | /bin/grep -B 1 rt2800usb | /bin/grep -o "Port [0-9]*" | /bin/grep -o "[0-9]*" | /usr/bin/python /opt/rdbox/boot/rdbox-bind_unbind_dongles.py
  mv -n /etc/network/interfaces /etc/network/interfaces.org
  ln -fs /etc/rdbox/network/interfaces /etc/network/interfaces
  cp -n /etc/rdbox/network/interfaces.d/master/* /etc/rdbox/network/interfaces.d/current
  sed -i '/^#ListenAddress 0.0.0.0$/c ListenAddress 192.168.179.1' /etc/ssh/sshd_config
  /bin/systemctl stop sshd.service
  /bin/systemctl stop networking.service
  /bin/systemctl start networking.service
  /bin/systemctl start sshd.service
  /usr/bin/touch /etc/rdbox/hostapd_be.deny
  sed -i "/^#bssid$/c bssid=`/sbin/ifconfig wlan1 | grep -o -E '([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}'`" /etc/rdbox/wpa_supplicant_be.conf
  /bin/systemctl enable rdbox-boot.service
  touch /var/lib/rdbox/.completed_first_session
  /bin/systemctl restart rdbox-boot.service
  rm -rf /var/lib/rdbox/.completed_first_session
  /bin/systemctl enable dnsmasq.service
  /bin/systemctl restart dnsmasq.service
  mkdir -p /usr/local/share/rdbox
  /bin/systemctl enable nfs-kernel-server.service
  /bin/systemctl start nfs-kernel-server.service
  http_proxy_size=`wc -c /etc/transproxy/http_proxy | awk '{print $1}'`
  no_proxy_size=`wc -c /etc/transproxy/no_proxy | awk '{print $1}'`
  if [ $http_proxy_size -gt 12 ] && [ $no_proxy_size -gt 10 ]; then
    /bin/systemctl enable transproxy.service
    /bin/systemctl restart transproxy.service
  else
    /bin/systemctl disable transproxy.service
    /bin/systemctl stop transproxy.service
  fi
  snap install helm --classic
elif [[ $hname =~ $regex_slave ]]; then
  /usr/bin/lsusb -t | /bin/grep -B 1 rt2800usb | /bin/grep -o "Port [0-9]*" | /bin/grep -o "[0-9]*" | /usr/bin/python /opt/rdbox/boot/rdbox-bind_unbind_dongles.py
  mv -n /etc/network/interfaces /etc/network/interfaces.org
  ln -fs /etc/rdbox/network/interfaces /etc/network/interfaces
  cp -n /etc/rdbox/network/interfaces.d/slave/* /etc/rdbox/network/interfaces.d/current
  /sbin/ifconfig wlan0 | grep -o -E '([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}' > /etc/rdbox/hostapd_be.deny
  sed -i "/^#bssid_blacklist$/c bssid_blacklist=`/sbin/ifconfig wlan1 | grep -o -E '([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}'`" /etc/rdbox/wpa_supplicant_be.conf
  /bin/systemctl stop sshd.service
  /bin/systemctl stop networking.service
  /bin/systemctl start networking.service
  /bin/systemctl start sshd.service
  /sbin/dhclient br0
  /bin/systemctl enable rdbox-boot.service
  touch /var/lib/rdbox/.completed_first_session
  /bin/systemctl restart rdbox-boot.service
  rm -rf /var/lib/rdbox/.completed_first_session
  /bin/systemctl disable systemd-networkd-wait-online.service
  /bin/systemctl mask systemd-networkd-wait-online.service
  sed -i '/^#timeout 60;$/c timeout 5;' /etc/dhcp/dhclient.conf
elif [[ $hname =~ $regex_vpnbridge ]]; then
  mv -n /etc/network/interfaces /etc/network/interfaces.org
  ln -fs /etc/rdbox/network/interfaces /etc/network/interfaces
  cp -n /etc/rdbox/network/interfaces.d/vpnbridge/* /etc/rdbox/network/interfaces.d/current
  ln -fs /etc/rdbox/wpa_supplicant_ap_bg.conf /etc/wpa_supplicant/wpa_supplicant.conf
  /bin/systemctl stop sshd.service
  /bin/systemctl stop networking.service
  /bin/systemctl start networking.service
  /bin/systemctl start sshd.service
  /sbin/ifup wlan10
  /sbin/dhclient wlan10 
  /sbin/ip addr del `ip -f inet -o addr show eth0|cut -d\  -f 7 | cut -d/ -f 1`/24 dev eth0
  /bin/systemctl enable softether-vpnbridge.service
  /bin/systemctl restart softether-vpnbridge.service
  sleep 30
  /usr/bin/vpncmd localhost:443 -server -in:/usr/local/etc/vpnbridge.in
  /bin/systemctl restart softether-vpnbridge.service
else
  mv -n /etc/network/interfaces /etc/network/interfaces.org
  ln -fs /etc/rdbox/network/interfaces /etc/network/interfaces
  cp -n /etc/rdbox/network/interfaces.d/others/* /etc/rdbox/network/interfaces.d/current
  ln -fs /etc/rdbox/wpa_supplicant_ap_bg.conf /etc/wpa_supplicant/wpa_supplicant.conf
  /bin/systemctl stop sshd.service
  /bin/systemctl stop networking.service
  /bin/systemctl start networking.service
  /bin/systemctl start sshd.service
  /sbin/ifup wlan10
  /sbin/dhclient wlan10 
fi

if [ -e '/boot/id_rsa' ]; then
  for user in `ls /home`; do
    home_dir=/home/$user
    mkdir -p -m 700 $home_dir/.ssh
    cp -n /boot/id_rsa $home_dir/.ssh/id_rsa
    chmod 600 $home_dir/.ssh/id_rsa
    chown -R $user:$user $home_dir/.ssh
  done
fi

if [ -e '/boot/id_rsa.pub' ]; then
  for user in `ls /home`; do
    home_dir=/home/$user
    mkdir -p -m 700 $home_dir/.ssh
    cat /boot/id_rsa.pub >> $home_dir/.ssh/authorized_keys
    chmod 600 $home_dir/.ssh/authorized_keys
    chown -R $user:$user $home_dir/.ssh
  done
fi

touch /var/lib/rdbox/.completed_first_session
rm /boot/id_rsa
rm /boot/id_rsa.pub

exit 0
