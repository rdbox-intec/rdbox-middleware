#!/bin/bash

export LC_ALL=C
export LANG=C

if [ "$(whoami)" != "root" ]; then
  echo "Require root privilege"
  exit 1
fi

regex_master='^.*master.*'
regex_slave='^.*slave.*'
regex_vpnbridge='^.*vpnbridge.*'
regex_simplexmst='^.*simplexmst.*'
regex_simplexslv='^.*simplexslv.*'
hname=$(/bin/hostname)
rdbox_type="other"
is_simple=false

if ! cat /var/lib/rdbox/.is_simple; then
  is_simple=false
else
  is_simple=$(cat /var/lib/rdbox/.is_simple)
fi

if [[ $hname =~ $regex_master ]]; then
  hostname_arr=()
  # shellcheck disable=SC2034
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

if [[ $rdbox_type =~ $regex_simplexmst ]]; then
  echo "master"
  ## final
  cp -rf /etc/.original.motd /etc/motd 

  ## Other
  systemctl disable ntp.service
  systemctl disable rdbox-boot.service
  mv /lib/systemd/system/.original.rdbox-boot.service /lib/systemd/system/rdbox-boot.service
  mv /etc/rdbox/.original.hostapd_ap_bg.conf /etc/rdbox/hostapd_ap_bg.conf 
  rm -rf /etc/rdbox/hostapd_be.deny
  systemctl disable transproxy.service

  ## NFS
  systemctl disable nfs-kernel-server.service
  rm -rf /usr/local/share/rdbox

  ## BIND9
  /bin/systemctl disable bind9
  mv /etc/bind/.original.named.conf.options /etc/bind/named.conf.options

  ## DNSMASQ
  /bin/systemctl disable dnsmasq.service
  rm -rf /var/lib/rdbox/dnsmasq.k8s_external_svc.hosts.conf
  rm -rf /etc/rdbox/dnsmasq.resolver.conf
  rm -rf /etc/rdbox/dnsmasq.hosts.conf
  mv /etc/rdbox/.original.dnsmasq.conf /etc/rdbox/dnsmasq.conf

  ## br0
  rm -rf /etc/rdbox/network/interfaces.d/current/*

  ## VPN
  systemctl disable softether-vpnclient.service

  ## Network
  unlink /etc/network/interfaces.d
  unlink /etc/network/interfaces
  mv /etc/network/interfaces.d.bak /etc/network/interfaces.d
  mv /etc/network/interfaces.org /etc/network/interfaces
elif [[ $rdbox_type =~ $regex_simplexslv ]]; then
  echo "slave"
  mv /etc/dhcp/.original.dhclient.conf /etc/dhcp/dhclient.conf
  systemctl disable ntp.service
  systemctl disable rdbox-boot.service
  mv /etc/rdbox/.original.hostapd_ap_bg.conf /etc/rdbox/hostapd_ap_bg.conf
else
  echo "other"
  unlink /etc/wpa_supplicant/wpa_supplicant.conf
  unlink /etc/network/interfaces.d
  unlink /etc/network/interfaces
  mv /etc/network/interfaces.d.bak /etc/network/interfaces.d
  mv /etc/network/interfaces.org /etc/network/interfaces
  systemctl disable ntp.service
fi

## Statement reset
rm -rf /var/lib/rdbox/.completed_first_session

## Install Hook Script
{
  echo "[Unit]"
  echo "Description=rdbox developers reset service"
  echo "After=network-online.target"
  echo ""
  echo "[Service]"
  echo "Type=oneshot "
  echo "ExecStart=/bin/bash /home/${SUDO_USER}/rdbox-middleware/for_developers/.initjob.bash"
  echo "RemainAfterExit=yes"
  echo ""
  echo "[Install]"
  echo "WantedBy=network-online.target"
} > /lib/systemd/system/rdbox-developers-reset.service
systemctl enable rdbox-developers-reset.service

## Restart
restart