#!/bin/bash

regex_master='^.*master.*'
regex_slave='^.*slave.*'
regex_vpnbridge='^.*vpnbridge.*'
hname=`/bin/hostname`

# Pickup the hostname changes
/bin/systemctl restart avahi-daemon

chmod 777 /var/lib/rdbox
chmod 777 /var/log/rdbox

if [[ $hname =~ $regex_master ]]; then
  /usr/sbin/hwinfo --wlan | /bin/grep "SysFS ID" | /bin/grep "usb" | /bin/sed -e 's/^[ ]*//g' | /usr/bin/awk '{print $3}' | /usr/bin/awk -F "/" '{ print $NF }' | /usr/bin/python /opt/rdbox/boot/rdbox-bind_unbind_dongles.py
  mv -n /etc/network/interfaces /etc/network/interfaces.org
  ln -fs /etc/rdbox/network/interfaces /etc/network/interfaces
  cp -n /etc/rdbox/network/interfaces.d/master/* /etc/rdbox/network/interfaces.d/current
  /bin/systemctl stop sshd.service
  /bin/systemctl stop networking.service
  /bin/systemctl start networking.service
  /bin/systemctl start sshd.service
  /usr/bin/touch /etc/rdbox/hostapd_be.deny
  sed -i "/^#bssid$/c bssid=`/sbin/ifconfig wlan1 | grep -o -E '([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}'`" /etc/rdbox/wpa_supplicant_be.conf
  /bin/systemctl enable rdbox-boot.service
  /bin/systemctl restart rdbox-boot.service
#################################################################
# config dnsmqsq
echo 'no-dhcp-interface=eth0,wlan0,wlan1,wlan2,wlan3
listen-address=127.0.0.1,192.168.179.1
interface=br0
domain=rdbox.lan
expand-hosts
no-hosts
server=//192.168.179.1
server=/rdbox.lan/192.168.179.1
server=/179.168.192.in-addr.arpa/192.168.179.1
local=/rdbox.lan/
resolv-file=/etc/rdbox/dnsmasq.resolver.conf
dhcp-leasefile=/etc/rdbox/dnsmasq.leases
addn-hosts=/etc/rdbox/dnsmasq.hosts.conf
addn-hosts=/etc/rdbox/dnsmasq.k8s_external_svc.hosts.conf
dhcp-range=192.168.179.11,192.168.179.254,255.255.255.0,30d
dhcp-option=option:router,192.168.179.1
dhcp-option=option:dns-server,192.168.179.1
dhcp-option=option:ntp-server,192.168.179.1
port=53
' > /etc/rdbox/dnsmasq.conf
echo '192.168.179.1 rdbox-master-00 rdbox-master-00.rdbox.lan
192.168.179.2 rdbox-k8s-master rdbox-k8s-master.rdbox.lan
192.168.179.3 rdbox-k8s-vpn rdbox-k8s-vpn.rdbox.lan
' > /etc/rdbox/dnsmasq.hosts.conf
echo 'nameserver 8.8.8.8
nameserver 8.8.4.4
' > /etc/rdbox/dnsmasq.resolver.conf
touch /etc/rdbox/dnsmasq.k8s_external_svc.hosts.conf
#################################################################
  /bin/systemctl enable dnsmasq.service
  /bin/systemctl restart dnsmasq.service
  mkdir -p /usr/local/share/rdbox
  echo "/usr/local/share/rdbox `ip route | grep br0 | awk '{print $1}'`(rw,sync,no_subtree_check,no_root_squash,no_all_squash)" >> /etc/exports
  /bin/systemctl enable nfs-kernel-server.service
  /bin/systemctl start nfs-kernel-server.service
  http_proxy_size=`wc -c /etc/transproxy/http_proxy | awk '{print $1}'`
  no_proxy_size=`wc -c /etc/transproxy/no_proxy | awk '{print $1}'`
  if [ $http_proxy_size -gt 12 ]; then
    /bin/systemctl enable transproxy.service
    /bin/systemctl restart transproxy.service
  else
    /bin/systemctl disable transproxy.service
    /bin/systemctl stop transproxy.service
  fi
  snap install helm --classic
elif [[ $hname =~ $regex_slave ]]; then
  /usr/sbin/hwinfo --wlan | /bin/grep "SysFS ID" | /bin/grep "usb" | /bin/sed -e 's/^[ ]*//g' | /usr/bin/awk '{print $3}' | /usr/bin/awk -F "/" '{ print $NF }' | /usr/bin/python /opt/rdbox/boot/rdbox-bind_unbind_dongles.py
  mv -n /etc/network/interfaces /etc/network/interfaces.org
  ln -fs /etc/rdbox/network/interfaces /etc/network/interfaces
  cp -n /etc/rdbox/network/interfaces.d/slave/* /etc/rdbox/network/interfaces.d/current
  /sbin/ifconfig wlan0 | grep -o -E '([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}' > /etc/rdbox/hostapd_be.deny
  sed -i "/^#bssid_blacklist$/c bssid_blacklist=`/sbin/ifconfig wlan1 | grep -o -E '([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}'`" /etc/rdbox/wpa_supplicant_be.conf
  /bin/systemctl stop sshd.service
  /bin/systemctl stop networking.service
  /bin/systemctl start networking.service
  /bin/systemctl start sshd.service
  /bin/systemctl enable rdbox-boot.service
  /bin/systemctl restart rdbox-boot.service
  /sbin/dhclient br0
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
  rm -rf /boot/id_rsa
fi

if [ -e '/boot/id_rsa.pub' ]; then
  for user in `ls /home`; do
    home_dir=/home/$user
    mkdir -p -m 700 $home_dir/.ssh
    cat /boot/id_rsa.pub >> $home_dir/.ssh/authorized_keys
    chmod 600 $home_dir/.ssh/authorized_keys
    chown -R $user:$user $home_dir/.ssh
  done
  rm -rf /boot/id_rsa.pub
fi

sed -i "s/HypriotOS/RDBOX based on HypriotOS/g" /etc/motd
sed -i "/HypriotOS/a \
. \n \
            .___. \n \
           /___/| \n \
           |   |/ \n \
           .---.  \n \
           RDBOX  \n \
- A Robotics Developers BOX - " /etc/motd


exit 0
