#!/bin/bash
export LC_ALL=C
export LANG=C

source /opt/rdbox/boot/util_for_network_connection.bash
source /opt/rdbox/boot/util_for_ip_addresses.bash

DNS_AUTHORITATIVE_PORT="5353"
regex_master='^.*master.*'
regex_slave='^.*slave.*'
regex_vpnbridge='^.*vpnbridge.*'
regex_simplexmst='^.*simplexmst.*'
regex_simplexslv='^.*simplexslv.*'
hname=$(/bin/hostname)
fname=$(/bin/hostname -f)
rdbox_type="other"
is_simple=false
is_active_yoursite_wifi=false

check_active_yoursite_wifi () {
  word_count=$(< /etc/rdbox/wpa_supplicant_yoursite.conf sed 's/^[ \t]*//' | grep -E "^psk=.*" | wc -c)
  word_line=$(< /etc/rdbox/wpa_supplicant_yoursite.conf sed 's/^[ \t]*//' | grep -Ec "^psk=.*")
  if [ "$word_line" -eq 0 ]; then
    is_active_yoursite_wifi=false
    return 0
  fi
  counter=$((word_count / word_line))
  if [ "$counter" -gt 12 ]; then
    is_active_yoursite_wifi=true
    return 0
  fi
}

echo "$(date) The first session process is start."

declare -A HOSTNAME_PART;
HOSTNAME_PART=(
  ["PREFIX"]=0
  ["TYPE"]=1
  ['SUFFIX']=2
)

if ! cat /var/lib/rdbox/.is_simple; then
  is_simple=false
else
  is_simple=$(cat /var/lib/rdbox/.is_simple)
fi

if [[ $hname =~ $regex_master ]]; then
  hostname_arr=()
  IFS=" " read -r -a hostname_arr <<< "$(hostname | tr -s '-' ' ')"
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

if [[ $rdbox_type =~ $regex_simplexmst ]]; then
  # INTERFACE #################################################################
  {
    echo 'SUBSYSTEM=="net", ACTION=="add", DRIVERS=="?*", ATTR{address}=="b8:27:eb:??:??:??", ATTR{dev_id}=="0x0", ATTR{type}=="1", KERNEL=="eth*", NAME="eth0"'
    echo 'SUBSYSTEM=="net", ACTION=="add", DRIVERS=="?*", ATTR{address}=="b8:27:eb:??:??:??", ATTR{dev_id}=="0x0", ATTR{type}=="1", KERNEL=="wlan*", NAME="wlan0"'
    echo 'SUBSYSTEM=="net", ACTION=="add", DRIVERS=="?*", ATTR{address}=="dc:a6:32:??:??:??", ATTR{dev_id}=="0x0", ATTR{type}=="1", KERNEL=="eth*", NAME="eth0"'
    echo 'SUBSYSTEM=="net", ACTION=="add", DRIVERS=="?*", ATTR{address}=="dc:a6:32:??:??:??", ATTR{dev_id}=="0x0", ATTR{type}=="1", KERNEL=="wlan*", NAME="wlan0"'
  } > /etc/udev/rules.d/70-persistent-net.rules
  /usr/sbin/hwinfo --wlan | /bin/grep "SysFS ID" | /bin/grep "usb" | /bin/sed -e 's/^[ ]*//g' | /usr/bin/awk '{print $3}' | /usr/bin/awk -F "/" '{ print $NF }' | /usr/bin/python /opt/rdbox/boot/rdbox-bind_unbind_dongles.py
  mv /etc/network/interfaces /etc/network/interfaces.org
  ln -fs /etc/rdbox/network/interfaces /etc/network/interfaces
  cp -n /etc/rdbox/network/interfaces.d/simplexmst/* /etc/rdbox/network/interfaces.d/current
  mv /etc/network/interfaces.d /etc/network/interfaces.d.bak
  ln -fs /etc/rdbox/network/interfaces.d/current /etc/network/interfaces.d
  /bin/systemctl stop networking.service
  /bin/systemctl start networking.service
  ## For VPN ######################################################
  check_active_yoursite_wifi
  if $is_active_yoursite_wifi; then
    if ! connect_wifi_with_timeout -i wlan0 -c /etc/rdbox/wpa_supplicant_yoursite.conf; then
      echo 'ERR: Wi-Fi connection failed.'
      return 1
    else
      if ! wait_dhclient wlan0; then
        echo 'ERR: RDBOX could not get an IP address from your Wi-Fi access point.'
        return 2
      fi
    fi
  else
    if ! connect_ether; then
      echo 'ERR: RDBOX could not connect to your wired network.'
      return 3
    fi
  fi
  sleep 15
  /bin/systemctl enable softether-vpnclient.service
  /bin/systemctl restart softether-vpnclient.service
  /usr/bin/vpncmd localhost -client -in:/usr/local/etc/vpnbridge.in
  sleep 15
  wait_dhclient vpn_rdbox
  ip_vpnrdbox_with_cidr=$(ip -f inet -o addr show vpn_rdbox|cut -d\  -f 7 | tr -d '\n')
  ip_vpnrdbox=$(ip -f inet -o addr show vpn_rdbox|cut -d\  -f 7 | cut -d/ -f 1 | tr -d '\n')
  first_addr_vpnrdbox=$(cidr_default_gw "$ip_vpnrdbox_with_cidr")
  ip_vpnrdbox_cidr_netmask=$(cidr_netmask "${ip_vpnrdbox_with_cidr}")
  ip_vpnrdbox_fourth=$(cut -d'.' -f4 <<<"${ip_vpnrdbox}")
  {
    echo "auto br0"
    echo "allow-hotplug br0"
    echo "iface br0 inet static"
    echo "  address 192.168.${ip_vpnrdbox_fourth}.1"
    echo "  netmask 255.255.255.0"
    echo "  network 192.168.${ip_vpnrdbox_fourth}.0"
    echo "  broadcast 192.168.${ip_vpnrdbox_fourth}.255"
    echo "  dns-nameservers 192.168.${ip_vpnrdbox_fourth}.1 8.8.8.8 8.8.4.4"
    echo "  bridge_ports bat0"
    echo "  bridge_stp off"
    echo "  bridge_maxwait 1"
  } > /etc/rdbox/network/interfaces.d/current/br0
  /bin/systemctl stop sshd.service
  /bin/systemctl stop networking.service
  /bin/systemctl start networking.service
  /bin/systemctl start sshd.service
  #################################################################
  # DNS
  #################################################################
  ip_br0_with_cidr=$(ip -f inet -o addr show br0|cut -d\  -f 7 | tr -d '\n')
  ip_br0=$(ip -f inet -o addr show br0|cut -d\  -f 7 | cut -d/ -f 1 | tr -d '\n')
  first_addr_br0=$(cidr_default_gw "$ip_br0_with_cidr")
  netmask_br0=$(int_to_ip4 "$(netmask_of_prefix "$(cidr_prefix "$ip_br0_with_cidr")")")
  dhcp_min_addr=$(ipmax "$ip_br0_with_cidr" 25)
  dhcp_max_addr=$(cidr_default_gw_2 "$ip_br0_with_cidr")
  rdbox_domain=${hostname_arr[${HOSTNAME_PART['SUFFIX']}]}.${fname}
  # config dnsmqsq
  cp -rf /etc/rdbox/dnsmasq.conf /etc/rdbox/.original.dnsmasq.conf
  {
    echo "interface=br0"
    echo "interface=vpn_rdbox"
    echo "no-dhcp-interface=eth0,wlan0,vpn_rdbox"
    echo "expand-hosts"
    echo "no-hosts"
    echo "domain=${rdbox_domain}"
    echo "local=/${rdbox_domain}/"
    echo "resolv-file=/etc/rdbox/dnsmasq.resolver.conf"
    echo "dhcp-leasefile=/var/lib/rdbox/dnsmasq.leases"
    echo "addn-hosts=/etc/rdbox/dnsmasq.hosts.conf"
    echo "addn-hosts=/var/lib/rdbox/dnsmasq.k8s_external_svc.hosts.conf"
    echo "dhcp-range=${dhcp_min_addr},${dhcp_max_addr},${netmask_br0},12h"
    echo "dhcp-option=option:router,${ip_br0}"
    echo "dhcp-option=option:dns-server,${ip_br0}"
    echo "dhcp-option=option:ntp-server,${ip_br0}"
    echo "dhcp-option=option:classless-static-route,0.0.0.0/0,${ip_br0},${ip_vpnrdbox_cidr_netmask},${ip_br0}"
    echo "dhcp-option=option:domain-search,${rdbox_domain},hq.${fname}"
    echo "port=${DNS_AUTHORITATIVE_PORT}"
  } > /etc/rdbox/dnsmasq.conf
  {
    echo "${ip_br0} ${hname} ${hname}.${rdbox_domain}"
  } > /etc/rdbox/dnsmasq.hosts.conf
  touch /etc/rdbox/dnsmasq.resolver.conf
  source /opt/rdbox/boot/dns_from_dhcp_lease.bash eth0
  dns_ip_list=$(get_dns_from_dhcp_lease | awk '{$1="";print}')
  for line in $dns_ip_list
  do
    echo "nameserver ${line}" >> /tmp/.rdbox-dns
  done
  source /opt/rdbox/boot/dns_from_dhcp_lease.bash wlan0
  dns_ip_list=$(get_dns_from_dhcp_lease | awk '{$1="";print}')
  for line in $dns_ip_list
  do
    echo "nameserver ${line}" >> /tmp/.rdbox-dns
  done
  dns_ip_list=$(< /etc/rdbox/network/interfaces.d/current/br0 grep dns-nameservers | awk '{$1="";print}')
  for line in $dns_ip_list
  do
    if [ "$line" = "$first_addr_br0" ]; then
      continue
    fi
    echo "nameserver ${line}" >> /tmp/.rdbox-dns
  done
  awk '!colname[$2]++{print $1" "$2}' /tmp/.rdbox-dns | tee /etc/rdbox/dnsmasq.resolver.conf
  rm -rf /tmp/.rdbox-dns
  touch /var/lib/rdbox/dnsmasq.k8s_external_svc.hosts.conf
  /bin/systemctl enable dnsmasq.service
  /bin/systemctl restart dnsmasq.service
  # config bind9
  cp -rf /etc/bind/named.conf.options /etc/bind/.original.named.conf.options
  {
    echo 'options {'
    echo '        directory "/var/cache/bind";'
    echo ""
    echo "        listen-on port 53 { 127.0.0.1; ${ip_br0_with_cidr}; };"
    echo "        listen-on-v6 { none; };"
    echo ""
    echo "        forward only;"
    echo "        forwarders  { ${ip_br0} port ${DNS_AUTHORITATIVE_PORT}; };"
    echo ""
    echo "        dnssec-validation no;"
    echo "        auth-nxdomain no;"
    echo "        version none;"
    echo "};"
    echo ""
    echo "zone ${fname} IN {"
    echo "        type forward;"
    echo "        forward only;"
    echo "        forwarders { 192.168.1.179 port ${DNS_AUTHORITATIVE_PORT}; };"
    echo "};"
    echo "zone ${rdbox_domain} IN {"
    echo "        type forward;"
    echo "        forward only;"
    echo "        forwarders { ${ip_br0} port ${DNS_AUTHORITATIVE_PORT}; };"
    echo "};"
    echo "zone ${ip_vpnrdbox_fourth}.168.192.in-addr.arpa {"
    echo "        type forward;"
    echo "        forward only;"
    echo "        forwarders { ${ip_br0} port ${DNS_AUTHORITATIVE_PORT}; };"
    echo "};"
    echo ""
    echo "zone hq.${fname} IN {"
    echo "        type forward;"
    echo "        forward only;"
    echo "        forwarders { ${first_addr_vpnrdbox} port ${DNS_AUTHORITATIVE_PORT}; };"
    echo "};"
    echo "zone 0.168.192.in-addr.arpa {"
    echo "        type forward;"
    echo "        forward only;"
    echo "        forwarders { ${first_addr_vpnrdbox} port ${DNS_AUTHORITATIVE_PORT}; };"
    echo "};"
    echo "zone 1.168.192.in-addr.arpa {"
    echo "        type forward;"
    echo "        forward only;"
    echo "        forwarders { ${first_addr_vpnrdbox} port ${DNS_AUTHORITATIVE_PORT}; };"
    echo "};"
    echo "zone 2.168.192.in-addr.arpa {"
    echo "        type forward;"
    echo "        forward only;"
    echo "        forwarders { ${first_addr_vpnrdbox} port ${DNS_AUTHORITATIVE_PORT}; };"
    echo "};"
    echo "zone 3.168.192.in-addr.arpa {"
    echo "        type forward;"
    echo "        forward only;"
    echo "        forwarders { ${first_addr_vpnrdbox}  port ${DNS_AUTHORITATIVE_PORT}; };"
    echo "};"
  } > /etc/bind/named.conf.options
  /bin/systemctl enable bind9
  /bin/systemctl restart bind9
  #################################################################
  mkdir -p /usr/local/share/rdbox
  echo "/usr/local/share/rdbox $(ip route | grep br0 | awk '{print $1}')(rw,sync,no_subtree_check,no_root_squash,no_all_squash)" >> /etc/exports
  exportfs -ra
  /bin/systemctl enable nfs-kernel-server.service
  /bin/systemctl start nfs-kernel-server.service
  http_proxy_size=$(wc -c /etc/transproxy/http_proxy | awk '{print $1}')
  no_proxy_size=$(wc -c /etc/transproxy/no_proxy | awk '{print $1}')
  if [ "$http_proxy_size" -gt 12 ]; then
    if [ "$no_proxy_size" -gt 10 ]; then
      /bin/systemctl enable transproxy.service
      /bin/systemctl restart transproxy.service
    fi
  else
    /bin/systemctl disable transproxy.service
    /bin/systemctl stop transproxy.service
  fi
  ## For VPN.
  /bin/systemctl restart softether-vpnclient.service
  ## For RDBOX.
  /usr/bin/touch /etc/rdbox/hostapd_be.deny
  cp /etc/rdbox/hostapd_ap_bg.conf /etc/rdbox/.original.hostapd_ap_bg.conf
  sed -i -e '/^interface\=/c\interface\=awlan1' /etc/rdbox/hostapd_ap_bg.conf
  sed -i -e '/^ht\_capab\=/c\ht_capab\=\[HT40\]\[SHORT\-GI\-20\]' /etc/rdbox/hostapd_ap_bg.conf
  sed -i -e '/^channel\=/c\channel\=1' /etc/rdbox/hostapd_ap_bg.conf
  sed -i -e '/^hw_mode\=/c\hw_mode\=g' /etc/rdbox/hostapd_ap_bg.conf
  sed -i -e '/^interface\=/c\interface\=awlan0' /etc/rdbox/hostapd_be.conf
  sed -i -e '/^ht\_capab\=/c\ht_capab\=\[HT40\]\[SHORT\-GI\-20\]' /etc/rdbox/hostapd_be.conf
  sed -i -e '/^channel\=/c\channel\=1' /etc/rdbox/hostapd_be.conf
  sed -i -e '/^hw_mode\=/c\hw_mode\=g' /etc/rdbox/hostapd_be.conf
  cp /lib/systemd/system/rdbox-boot.service /lib/systemd/system/.original.rdbox-boot.service
  if $is_active_yoursite_wifi; then
    echo "alive monitoring: wpa and hostapd."
  else
    echo "alive monitoring: hostapd."
    sed -i '/wpa_supplicant.pid/d' /lib/systemd/system/rdbox-boot.service
  fi
  /bin/systemctl enable rdbox-boot.service
  /bin/systemctl restart rdbox-boot.service
  ## install Helm.
  systemctl enable ntp.service
  systemctl restart ntp.service
  sleep 30
  apt update
  snap install helm --classic
  helm repo add stable https://kubernetes-charts.storage.googleapis.com/
  helm repo add bitnami https://charts.bitnami.com/bitnami
elif [[ $rdbox_type =~ $regex_simplexslv ]]; then
  /usr/sbin/hwinfo --wlan | /bin/grep "SysFS ID" | /bin/grep "usb" | /bin/sed -e 's/^[ ]*//g' | /usr/bin/awk '{print $3}' | /usr/bin/awk -F "/" '{ print $NF }' | /usr/bin/python /opt/rdbox/boot/rdbox-bind_unbind_dongles.py
  mv -n /etc/network/interfaces /etc/network/interfaces.org
  ln -fs /etc/rdbox/network/interfaces /etc/network/interfaces
  cp -f /etc/rdbox/network/interfaces.d/simplexslv/* /etc/rdbox/network/interfaces.d/current
  mv /etc/network/interfaces.d /etc/network/interfaces.d.bak
  ln -fs /etc/rdbox/network/interfaces.d/current /etc/network/interfaces.d
  /sbin/ifconfig wlan0 | grep -o -E '([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}' > /etc/rdbox/hostapd_be.deny
  cp -rf /etc/rdbox/hostapd_ap_bg.conf /etc/rdbox/.original.hostapd_ap_bg.conf
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
  sed -i "/^#bssid_blacklist$/c bssid_blacklist=$(/sbin/ifconfig awlan0 | grep -o -E '([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}')" /etc/rdbox/wpa_supplicant_be.conf
  /bin/systemctl enable rdbox-boot.service
  /bin/systemctl restart rdbox-boot.service
  wait_dhclient br0
  if [ ! -s "/etc/resolv.conf" ]; then
    unlink /etc/resolv.conf || :
    rm -rf /etc/resolv.conf || :
    ln -s /etc/resolvconf/run/resolv.conf /etc/resolv.conf
  fi
  /bin/systemctl disable systemd-networkd-wait-online.service
  /bin/systemctl mask systemd-networkd-wait-online.service
  cp -rf /etc/dhcp/dhclient.conf /etc/dhcp/.original.dhclient.conf
  sed -i '/^#timeout 60;$/c timeout 5;' /etc/dhcp/dhclient.conf
  systemctl enable ntp.service
  systemctl restart ntp.service
  sleep 30
  apt update
else
  mv -n /etc/network/interfaces /etc/network/interfaces.org
  ln -fs /etc/rdbox/network/interfaces /etc/network/interfaces
  cp -n /etc/rdbox/network/interfaces.d/others/* /etc/rdbox/network/interfaces.d/current
  mv /etc/network/interfaces.d /etc/network/interfaces.d.bak
  ln -fs /etc/rdbox/network/interfaces.d/current /etc/network/interfaces.d
  ln -fs /etc/rdbox/wpa_supplicant_ap_bg.conf /etc/wpa_supplicant/wpa_supplicant.conf
  /bin/systemctl stop sshd.service
  /bin/systemctl stop networking.service
  /bin/systemctl start networking.service
  /bin/systemctl start sshd.service
  /sbin/ifup wlan0
  if [ "$(/sbin/ip -f inet -o addr show wlan0 | cut -d\  -f 7 | cut -d/ -f 1 | wc -l)" -gt  0 ] ; then
    wait_dhclient wlan0
  fi
  if [ ! -s "/etc/resolv.conf" ]; then
    unlink /etc/resolv.conf || :
    rm -rf /etc/resolv.conf || :
    ln -s /etc/resolvconf/run/resolv.conf /etc/resolv.conf
  fi
  systemctl enable ntp.service
  systemctl restart ntp.service
  sleep 30
  apt update
fi

if [ -e '/boot/id_rsa' ]; then
  for home_dir in /home/*; do
    user=$(basename "$home_dir")
    mkdir -p "$home_dir"/.ssh
    chmod 700 "$home_dir"/.ssh
    cp -n /boot/id_rsa "$home_dir"/.ssh/id_rsa
    chmod 600 "$home_dir"/.ssh/id_rsa
    chown -R "$user":"$user" "$home_dir"/.ssh
  done
  rm -rf /boot/id_rsa
fi

if [ -e '/boot/id_rsa.pub' ]; then
  for home_dir in /home/*; do
    user=$(basename "$home_dir")
    mkdir -p "$home_dir"/.ssh
    chmod 700 "$home_dir"/.ssh
    cat /boot/id_rsa.pub >> "$home_dir"/.ssh/authorized_keys
    chmod 600 "$home_dir"/.ssh/authorized_keys
    chown -R "$user":"$user" "$home_dir"/.ssh
  done
  rm -rf /boot/id_rsa.pub
fi

cp -rf /etc/motd /etc/.original.motd
sed -i "s/HypriotOS/RDBOX based on HypriotOS/g" /etc/motd
sed -i "/HypriotOS/a \
. \n \
            .___. \n \
           /___/| \n \
           |   |/ \n \
           .---.  \n \
           RDBOX  \n \
- A Robotics Developers BOX - " /etc/motd

echo "$(date) The first session process is complete."

exit 0
