#!/bin/bash
export LC_ALL=C
export LANG=C

regex_master='^.*master.*'
regex_slave='^.*slave.*'
regex_vpnbridge='^.*vpnbridge.*'
regex_simplexmst='^.*simplexmst.*'
regex_simplexslv='^.*simplexslv.*'
hname=$(/bin/hostname)
is_simple=false
rdbox_type="other"

if ! cat /var/lib/rdbox/.is_simple; then
  is_simple=false
else
  is_simple=$(cat /var/lib/rdbox/.is_simple)
fi

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

echo $$ > /var/lib/rdbox/.completed_first_session

if [ ! -e "/etc/rdbox/hostapd_ap_an.conf" ];then
  echo "/etc/rdbox/hostapd_ap_an.conf File not exists."
  cp -rf /etc/rdbox/hostapd_ap_an.conf.sample /etc/rdbox/hostapd_ap_an.conf
fi
if [ ! -e "/etc/rdbox/hostapd_ap_bg.conf" ];then
  echo "/etc/rdbox/hostapd_ap_bg.conf File not exists."
  cp -rf /etc/rdbox/hostapd_ap_bg.conf.sample /etc/rdbox/hostapd_ap_bg.conf
fi
if [ ! -e "/etc/rdbox/hostapd_be.conf" ];then
  echo "/etc/rdbox/hostapd_be.conf File not exists."
  cp -rf /etc/rdbox/hostapd_be.conf.sample /etc/rdbox/hostapd_be.conf
fi
if [ ! -e "/etc/rdbox/wpa_supplicant_be.conf" ];then
  echo "wpa_supplicant_be.conf File not exists."
  cp -rf /etc/rdbox/wpa_supplicant_be.conf.sapmle /etc/rdbox/wpa_supplicant_be.conf
fi
if [ ! -e "/etc/rdbox/wpa_supplicant_ap_bg.conf" ];then
  echo "wpa_supplicant_ap_bg.conf File not exists."
  cp -rf /etc/rdbox/wpa_supplicant_ap_bg.conf.sapmle /etc/rdbox/wpa_supplicant_ap_bg.conf
fi
if [ ! -e "/etc/rdbox/rdbox_cli.conf" ];then
  echo "/etc/rdbox/rdbox_cli.conf File not exists."
  cp -rf /etc/rdbox/rdbox_cli.conf.sample /etc/rdbox/rdbox_cli.conf
fi

/bin/bash /opt/rdbox/boot/rdbox-first_session_sub.bash >> /var/log/rdbox/rdbox_first_session.log 2>&1

if [[ $rdbox_type =~ $regex_master ]]; then
  echo "master" > /var/lib/rdbox/.completed_first_session
elif [[ $rdbox_type =~ $regex_slave ]]; then
  echo "slave" > /var/lib/rdbox/.completed_first_session
elif [[ $rdbox_type =~ $regex_vpnbridge ]]; then
  echo "vpnbridge" > /var/lib/rdbox/.completed_first_session
elif [[ $rdbox_type =~ $regex_simplexmst ]]; then
  echo "simplexmst" > /var/lib/rdbox/.completed_first_session
elif [[ $rdbox_type =~ $regex_simplexslv ]]; then
  echo "simplexslv" > /var/lib/rdbox/.completed_first_session
else
  echo "other" > /var/lib/rdbox/.completed_first_session
fi

exit 0
