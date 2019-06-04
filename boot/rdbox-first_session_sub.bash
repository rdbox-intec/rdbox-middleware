#!/bin/bash
export LC_ALL=C
export LANG=C

source /opt/rdbox/boot/util_for_ip_addresses.bash

echo "`date` The first session process is start."

regex_master='^.*master.*'
regex_slave='^.*slave.*'
regex_vpnbridge='^.*vpnbridge.*'
regex_simplexmst='^.*simplexmst.*'
regex_simplexslv='^.*simplexslv.*'
hname=`/bin/hostname`
fname=`/bin/hostname -f`
is_simple=`cat /var/lib/rdbox/.is_simple`
if [ $? -ne 0 ]; then
  is_simple=false
fi
rdbox_type="other"
if [[ $hname =~ $regex_master ]]; then
  if "${is_simple}"; then
    rdbox_type="simplexmst"
  else
    rdbox_type="master"
  fi
elif [[ $hname =~ $regex_slave ]]; then
  if "${is_simple}"; then
    rdbox_type="simplexslv"
  else
    rdbox_type="slave"
  fi
elif [[ $hname =~ $regex_vpnbridge ]]; then
  rdbox_type="vpnbridge"
else
  rdbox_type="other"
fi

# Pickup the hostname changes
/bin/systemctl restart avahi-daemon

chmod 777 /var/lib/rdbox
chmod 777 /var/log/rdbox

if [[ $rdbox_type =~ $regex_master ]]; then
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
# DNS
#################################################################
ip_br0_with_cidr=`ip -f inet -o addr show br0|cut -d\  -f 7 | tr -d '\n'`
ip_br0=`ip -f inet -o addr show br0|cut -d\  -f 7 | cut -d/ -f 1 | tr -d '\n'`
cidr_no=$(cidr_prefix $ip_br0_with_cidr)
first_addr=$(cidr_default_gw $ip_br0_with_cidr)
netmask_br0=$(int_to_ip4 $(netmask_of_prefix $(cidr_prefix $ip_br0_with_cidr)))
arpa_no=$(in-addr_arpa $ip_br0_with_cidr)
dhcp_min_addr=$(ipmax $ip_br0_with_cidr 25)
dhcp_max_addr=$(cidr_default_gw_2 $ip_br0_with_cidr)
k8smst_addr=$(ipmax $(cidr_default_gw $ip_br0_with_cidr) 2)
k8svpn_addr=$(ipmax $(cidr_default_gw $ip_br0_with_cidr) 3)
# config dnsmqsq
echo "no-dhcp-interface=eth0,wlan0,wlan1,wlan2,wlan3
listen-address=127.0.0.1,${ip_br0}
interface=br0
domain=${fname}
expand-hosts
no-hosts
server=//${ip_br0}
server=/${fname}/${ip_br0}
server=/${arpa_no}.in-addr.arpa/${ip_br0}
local=/${fname}/
resolv-file=/etc/rdbox/dnsmasq.resolver.conf
dhcp-leasefile=/etc/rdbox/dnsmasq.leases
addn-hosts=/etc/rdbox/dnsmasq.hosts.conf
addn-hosts=/etc/rdbox/dnsmasq.k8s_external_svc.hosts.conf
dhcp-range=${dhcp_min_addr},${dhcp_max_addr},${netmask_br0},30d
dhcp-option=option:router,${ip_br0}
dhcp-option=option:dns-server,${ip_br0}
dhcp-option=option:ntp-server,${ip_br0}
port=53
" > /etc/rdbox/dnsmasq.conf
echo "${ip_br0} ${hname} ${hname}.${fname}
${k8smst_addr} rdbox-k8s-master rdbox-k8s-master.${fname}
${k8svpn_addr} rdbox-k8s-vpn rdbox-k8s-vpn.${fname}
" > /etc/rdbox/dnsmasq.hosts.conf
echo -n "" > /etc/rdbox/dnsmasq.resolver.conf
dns_ip_list=`cat /etc/rdbox/network/interfaces.d/current/br0 | grep dns-nameservers | awk '{$1="";print}'`
for line in `echo $dns_ip_list`
do
  if [ $line = $first_addr ]; then
    continue
  fi
  echo "nameserver $line " >> /etc/rdbox/dnsmasq.resolver.conf
done
touch /etc/rdbox/dnsmasq.k8s_external_svc.hosts.conf
#################################################################
  /bin/systemctl enable dnsmasq.service
  /bin/systemctl restart dnsmasq.service
  mkdir -p /usr/local/share/rdbox
  echo "/usr/local/share/rdbox `ip route | grep br0 | awk '{print $1}'`(rw,sync,no_subtree_check,no_root_squash,no_all_squash)" >> /etc/exports
  exportfs -ra
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
elif [[ $rdbox_type =~ $regex_slave ]]; then
  /usr/sbin/hwinfo --wlan | /bin/grep "SysFS ID" | /bin/grep "usb" | /bin/sed -e 's/^[ ]*//g' | /usr/bin/awk '{print $3}' | /usr/bin/awk -F "/" '{ print $NF }' | /usr/bin/python /opt/rdbox/boot/rdbox-bind_unbind_dongles.py
  mv -n /etc/network/interfaces /etc/network/interfaces.org
  ln -fs /etc/rdbox/network/interfaces /etc/network/interfaces
  cp -f /etc/rdbox/network/interfaces.d/slave/* /etc/rdbox/network/interfaces.d/current
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
elif [[ $rdbox_type =~ $regex_vpnbridge ]]; then
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
elif [[ $rdbox_type =~ $regex_simplexmst ]]; then
  /usr/sbin/hwinfo --wlan | /bin/grep "SysFS ID" | /bin/grep "usb" | /bin/sed -e 's/^[ ]*//g' | /usr/bin/awk '{print $3}' | /usr/bin/awk -F "/" '{ print $NF }' | /usr/bin/python /opt/rdbox/boot/rdbox-bind_unbind_dongles.py
  mv -n /etc/network/interfaces /etc/network/interfaces.org
  ln -fs /etc/rdbox/network/interfaces /etc/network/interfaces
  cp -n /etc/rdbox/network/interfaces.d/simplexmst/* /etc/rdbox/network/interfaces.d/current
  /bin/systemctl stop sshd.service
  /bin/systemctl stop networking.service
  /bin/systemctl start networking.service
  /bin/systemctl start sshd.service
  ip_br0_with_cidr=`ip -f inet -o addr show br0|cut -d\  -f 7 | tr -d '\n'`
  ip_br0=`ip -f inet -o addr show br0|cut -d\  -f 7 | cut -d/ -f 1 | tr -d '\n'`
  cidr_no=$(cidr_prefix $ip_br0_with_cidr)
  first_addr=$(cidr_default_gw $ip_br0_with_cidr)
  netmask_br0=$(int_to_ip4 $(netmask_of_prefix $(cidr_prefix $ip_br0_with_cidr)))
  arpa_no=$(in-addr_arpa $ip_br0_with_cidr)
  dhcp_min_addr=$(ipmax $ip_br0_with_cidr 25)
  dhcp_max_addr=$(cidr_default_gw_2 $ip_br0_with_cidr)
  k8smst_addr=$(ipmax $(cidr_default_gw $ip_br0_with_cidr) 2)
  k8svpn_addr=$(ipmax $(cidr_default_gw $ip_br0_with_cidr) 3)
#################################################################
# config dnsmqsq
echo "no-dhcp-interface=eth0,wlan10
listen-address=127.0.0.1,${ip_br0}
interface=br0
domain=${fname}
expand-hosts
no-hosts
server=//${ip_br0}
server=/${fname}/${ip_br0}
server=/${arpa_no}.in-addr.arpa/${ip_br0}
local=/${fname}/
resolv-file=/etc/rdbox/dnsmasq.resolver.conf
dhcp-leasefile=/etc/rdbox/dnsmasq.leases
addn-hosts=/etc/rdbox/dnsmasq.hosts.conf
addn-hosts=/etc/rdbox/dnsmasq.k8s_external_svc.hosts.conf
dhcp-range=${dhcp_min_addr},${dhcp_max_addr},${netmask_br0},30d
dhcp-option=option:router,${ip_br0}
dhcp-option=option:dns-server,${ip_br0}
dhcp-option=option:ntp-server,${ip_br0}
port=53
" > /etc/rdbox/dnsmasq.conf
echo "${ip_br0} ${hname} ${hname}.${fname}
${k8smst_addr} rdbox-k8s-master rdbox-k8s-master.${fname}
${k8svpn_addr} rdbox-k8s-vpn rdbox-k8s-vpn.${fname}
" > /etc/rdbox/dnsmasq.hosts.conf
echo -n "" > /etc/rdbox/dnsmasq.resolver.conf
dns_ip_list=`cat /etc/rdbox/network/interfaces.d/current/br0 | grep dns-nameservers | awk '{$1="";print}'`
for line in `echo $dns_ip_list`
do
  if [ $line = $first_addr ]; then
    continue
  fi
  echo "nameserver $line " >> /etc/rdbox/dnsmasq.resolver.conf
done
touch /etc/rdbox/dnsmasq.k8s_external_svc.hosts.conf
#################################################################
  /bin/systemctl enable dnsmasq.service
  /bin/systemctl restart dnsmasq.service
  mkdir -p /usr/local/share/rdbox
  echo "/usr/local/share/rdbox `ip route | grep br0 | awk '{print $1}'`(rw,sync,no_subtree_check,no_root_squash,no_all_squash)" >> /etc/exports
  exportfs -ra
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
  /bin/systemctl enable softether-vpnbridge.service
  /bin/systemctl restart softether-vpnbridge.service
  sleep 30
  sed -i -e '/BridgeCreate BRIDGE/c\BridgeCreate BRIDGE /DEVICE:br0 /TAP:yes' /usr/local/etc/vpnbridge.in
  /usr/bin/vpncmd localhost:443 -server -in:/usr/local/etc/vpnbridge.in
  /bin/systemctl restart softether-vpnbridge.service
  /usr/bin/touch /etc/rdbox/hostapd_be.deny
  sed -i -e '/^interface\=/c\interface\=wlan10' /etc/rdbox/hostapd_ap_bg.conf
  sed -i -e '/^ht\_capab\=/c\ht_capab\=\[HT40\]\[SHORT\-GI\-20\]' /etc/rdbox/hostapd_ap_bg.conf
  sed -i -e '/^channel\=/c\channel\=1' /etc/rdbox/hostapd_ap_bg.conf
  sed -i -e '/^hw_mode\=/c\hw_mode\=g' /etc/rdbox/hostapd_ap_bg.conf
  sed -i -e '/^interface\=/c\interface\=awlan0' /etc/rdbox/hostapd_be.conf
  sed -i -e '/^ht\_capab\=/c\ht_capab\=\[HT40\]\[SHORT\-GI\-20\]' /etc/rdbox/hostapd_be.conf
  sed -i -e '/^channel\=/c\channel\=1' /etc/rdbox/hostapd_be.conf
  sed -i -e '/^hw_mode\=/c\hw_mode\=g' /etc/rdbox/hostapd_be.conf
  /bin/systemctl enable rdbox-boot.service
  /bin/systemctl restart rdbox-boot.service
  snap install helm --classic
elif [[ $rdbox_type =~ $regex_simplexslv ]]; then
  /usr/sbin/hwinfo --wlan | /bin/grep "SysFS ID" | /bin/grep "usb" | /bin/sed -e 's/^[ ]*//g' | /usr/bin/awk '{print $3}' | /usr/bin/awk -F "/" '{ print $NF }' | /usr/bin/python /opt/rdbox/boot/rdbox-bind_unbind_dongles.py
  mv -n /etc/network/interfaces /etc/network/interfaces.org
  ln -fs /etc/rdbox/network/interfaces /etc/network/interfaces
  cp -f /etc/rdbox/network/interfaces.d/simplexslv/* /etc/rdbox/network/interfaces.d/current
  /sbin/ifconfig wlan10 | grep -o -E '([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}' > /etc/rdbox/hostapd_be.deny
  sed -i -e '/^interface\=/c\interface\=awlan1' /etc/rdbox/hostapd_ap_bg.conf
  sed -i -e '/^ht\_capab\=/c\ht_capab\=\[HT40\]\[SHORT\-GI\-20\]' /etc/rdbox/hostapd_ap_bg.conf
  sed -i -e '/^channel\=/c\channel\=1' /etc/rdbox/hostapd_ap_bg.conf
  sed -i -e '/^hw_mode\=/c\hw_mode\=g' /etc/rdbox/hostapd_ap_bg.conf
  sed -i -e '/^interface\=/c\interface\=awlan0' /etc/rdbox/hostapd_be.conf
  sed -i -e '/^ht\_capab\=/c\ht_capab\=\[HT40\]\[SHORT\-GI\-20\]' /etc/rdbox/hostapd_be.conf
  sed -i -e '/^channel\=/c\channel\=1' /etc/rdbox/hostapd_be.conf
  sed -i -e '/^hw_mode\=/c\hw_mode\=g' /etc/rdbox/hostapd_be.conf
  /bin/systemctl stop sshd.service
  /bin/systemctl stop networking.service
  /bin/systemctl start networking.service
  /bin/systemctl start sshd.service
  sed -i "/^#bssid_blacklist$/c bssid_blacklist=`/sbin/ifconfig awlan0 | grep -o -E '([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}'`" /etc/rdbox/wpa_supplicant_be.conf
  /bin/systemctl enable rdbox-boot.service
  /bin/systemctl restart rdbox-boot.service
  /sbin/dhclient br0
  /bin/systemctl disable systemd-networkd-wait-online.service
  /bin/systemctl mask systemd-networkd-wait-online.service
  sed -i '/^#timeout 60;$/c timeout 5;' /etc/dhcp/dhclient.conf
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

echo "`date` The first session process is complete."

exit 0
