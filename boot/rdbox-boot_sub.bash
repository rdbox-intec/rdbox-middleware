#!/bin/bash
export LC_ALL=C
export LANG=C

source /opt/rdbox/boot/util_for_network_connection.bash
source /opt/rdbox/boot/util_for_ip_addresses.bash

SSHD_TIMEOUT=120
WPA_AUTH_TIMEOUT=30
HOSTAPD_TIMEOUT=30
regex_vpnbridge='^.*vpnbridge.*'
regex_master='^.*master.*'
regex_slave='^.*slave.*'
regex_simplexmst='^.*simplexmst.*'
regex_simplexslv='^.*simplexslv.*'
is_simple_mesh=false
rdbox_type=''
hname=$(/bin/hostname)
RETRY_COUNT=5
WPA_LOG=/var/log/rdbox/rdbox_boot_wpa.log
HOSTAPD_LOG=/var/log/rdbox/rdbox_boot_hostapd.log
PIDFILE_SUPLICANT=/run/wpa_supplicant.pid
PIDFILE_HOSTAPD=/run/hostapd.pid
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

check_active_default_gw () {
  isActive=$(route | grep -c default)
  if [ "$isActive" = 0 ]; then
    echo "Not set Default gw"
    return 10
  else
    echo "Already set default gw"
  fi
  return 0
}

update_dnsinfo () {
  _addr_br0=$(/sbin/ifconfig br0 | grep 'inet' | cut -d: -f2 | awk '{ print $2}')
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
    if [ "$line" = "$_addr_br0" ]; then
      continue
    fi
    echo "nameserver ${line}" >> /tmp/.rdbox-dns
  done
  awk '!colname[$2]++{print $1" "$2}' /tmp/.rdbox-dns | tee /etc/rdbox/dnsmasq.resolver.conf
  rm -rf /tmp/.rdbox-dns
}

discrimination_model () {
  if ! cat /var/lib/rdbox/.is_simple; then
    is_simple=false
  else
    is_simple=$(cat /var/lib/rdbox/.is_simple)
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
}

wait_ssh () {
  COUNT=0
  while true
  do
    isAlive=$(pgrep -f "/usr/sbin/sshd" | wc -l)
    if [ "$isAlive" = 1 ]; then
      echo "sshd is running."
      break
    else
      echo "wait sshd..."
    fi
    if [ $COUNT -eq $SSHD_TIMEOUT ]; then
      echo "SSH RETRY OVER!"
      return 7
    fi
    sleep 1
    COUNT=$((COUNT + 1))
  done
  sleep 10
  return 0
}

check_batman () {
  checkBATMAN=$(/usr/sbin/batctl if | grep -vc grep)
  if [ "$checkBATMAN" = 2 ]; then
      echo "BATMAN is running."
  else
      echo "BATMAN is Bad."
      return 10
  fi
  return 0
}

check_device_simple () {
  if ! ifconfig eth0 > /dev/null 2>&1; then
    echo "Device named 'eth0' not found."
    return 8
  fi
  if ! iwconfig wlan0 > /dev/null 2>&1; then
    echo "Device named 'wlan0' not found. (Error.....)"
    return 8
  fi
  if ! iwconfig wlan1 > /dev/null 2>&1; then
    echo "Device named 'wlan1' not found. (Start with 0 Dongle Mode.)"
    echo "disable simple mesh"
    is_simple_mesh=false
  else
    echo "Enable simple mesh"
    is_simple_mesh=true
    ifup awlan0
    if [[ $rdbox_type =~ $regex_simplexslv ]]; then
      ifup awlan1
    fi
  fi
  return 0
}

watch_hostapd () {
  current_time=$1
  while read -rt ${HOSTAPD_TIMEOUT} line; do
    echo "  $line"
    if echo "$line" | grep -wq 'AP-ENABLED'; then
      echo "  hostapd OK!!"
      return 0
    fi
    # judge timeout
    if [ $(($(date +%s) - current_time)) -gt ${HOSTAPD_TIMEOUT} ]; then
      echo "  unmatch Timeout."
      return 1
    fi
  done
  echo "  read Timeout."
  return 2
}

startup_hostapd_with_timeout () {
  # hostapd #######################
  current_time=$(date +%s)
  /usr/sbin/hostapd -B -f $HOSTAPD_LOG -P $PIDFILE_HOSTAPD "$@"
  rtn=1
  { watch_hostapd "$current_time"; rtn=$?; kill -s INT "$(pgrep -a tail | grep -v /usr/bin/timeout | grep $HOSTAPD_LOG | awk '{ print $1 }')"; } < <(/usr/bin/timeout --signal=HUP "$((HOSTAPD_TIMEOUT + 10))"s /usr/bin/tail --follow=name --retry $HOSTAPD_LOG)
  if [ $rtn -eq 0 ]; then
    return 0
  else
    echo 'hostapd startup failed.'
    pkill -INT -f hostapd
    return 6
  fi
}

generate_MACAddress () {
  _eth0_addr=$(cat "$(find /sys/devices/platform -name eth0 2>/dev/null)"/address)
  _wlan_addr=$(cat "$(find /sys/devices/platform -name wlan0 2>/dev/null)"/address)
  _tmp_addr=$(echo $RANDOM | openssl md5 | sed 's/\(..\)/\1:/g' | cut -b16-23 | sed 's/^/b8:27:eb:/')
  while true; do
    _tmp_addr=$(echo $RANDOM | openssl md5 | sed 's/\(..\)/\1:/g' | cut -b16-23 | sed 's/^/b8:27:eb:/')
    if [ "$_tmp_addr" = "$_eth0_addr" ]; then
      continue
    fi
    if [ "$_tmp_addr" = "$_wlan_addr" ]; then
      continue
    else
      break
    fi
  done
  echo "${_tmp_addr//[\r\n]\+//}"
}

_simplexmst_wifi_simplemesh_wpa () {
  # 1 dongle
  if ! iw dev wlan1 interface add awlan0 type __ap; then
    return 1
  fi
  if ! /usr/sbin/batctl if add awlan0; then
    return 2
  fi
  if ! ifup awlan0; then
    return 3
  fi
  if ! iw dev wlan1 interface add awlan1 type __ap; then
    return 4
  fi
  if ! ifup awlan1; then
    return 5
  fi
  /bin/systemctl restart networking.service
  source /etc/rdbox/network/iptables.mstsimple.wlan0
  if ! connect_wifi_with_timeout -i wlan0 -c /etc/rdbox/wpa_supplicant_yoursite.conf; then
    return 6
  fi
  if ! wait_dhclient wlan0; then
    return 7
  fi
  return 0
}

_simplexmst_wifi_nomesh_hostapd () {
  # 0 dongle (Wi-Fi)
  if ! iw dev wlan0 interface add awlan1 type __ap; then
    return 1
  fi
  _mac_addr=$(generate_MACAddress)
  echo "A MAC address was generated for awlan1: $_mac_addr"
  if ! ifconfig awlan1 hw ether "$_mac_addr"; then
    return 2
  fi
  if ! ifup awlan1; then
    return 3
  fi
  sed -i -e '/^interface\=/c\interface\=awlan1' /etc/rdbox/hostapd_ap_bg.conf
  sed -i -e '/^bridge\=/c\#bridge\=br0' /etc/rdbox/hostapd_ap_bg.conf
  source /etc/rdbox/network/iptables.mstsimple.wlan0
  if ! startup_hostapd_with_timeout /etc/rdbox/hostapd_ap_bg.conf; then
    return 4
  fi
  return 0
}

_simplexmst_ether_simplemesh_hostapd () {
  # 1 dongle
  if ! iw dev wlan1 interface add awlan0 type __ap; then
    return 1
  fi
  if ! /usr/sbin/batctl if add awlan0; then
    return 2
  fi
  if ! ifup awlan0; then
    return 3
  fi
  if ! iw dev wlan1 interface add awlan1 type __ap; then
    return 4
  fi
  if ! ifup awlan1; then
    return 5
  fi
  /bin/systemctl restart networking.service
  source /etc/rdbox/network/iptables.mstsimple.eth0
  connect_ether
  ret=$?
  if [ "$ret" -gt 0 ]; then
    return 6
  fi
  sed -i -e '/^interface\=/c\interface\=wlan0' /etc/rdbox/hostapd_ap_bg.conf
  if ! startup_hostapd_with_timeout /etc/rdbox/hostapd_ap_bg.conf /etc/rdbox/hostapd_be.conf; then
    return 7
  fi
  return 0
}

_simplexmst_wifi_nomesh_wpa () {
  # 0 dongle (Wi-Fi)
  if ! connect_wifi_with_timeout -i wlan0 -c /etc/rdbox/wpa_supplicant_yoursite.conf; then
    return 1
  fi
  if ! wait_dhclient wlan0; then
    return 2
  fi
  sleep 30
  if ! brctl addif br0 awlan1; then
    return 3
  fi
  return 0
}


for_simplexmst () {
  echo "simple(master)"
  REGISTERD_WIFI_DEV=$(grep -o 'SUBSYSTEM' /etc/udev/rules.d/70-persistent-net.rules | wc -l)
  if [ "$REGISTERD_WIFI_DEV" -eq 2 ]; then
    /usr/sbin/hwinfo --wlan | /bin/grep "SysFS ID" | /bin/grep "usb" | /bin/sed -e 's/^[ ]*//g' | /usr/bin/awk '{print $3}' | /usr/bin/awk -F "/" '{ print $NF }' | /usr/bin/python /opt/rdbox/boot/rdbox-bind_unbind_dongles.py
  fi
  if ! check_device_simple; then
    /bin/echo "Do not found device!"
    return 2
  fi
  COUNT=0
  ret=9
  while true; do
    pkill -INT -f hostapd
    pkill -INT -f wpa_supplicant
    sleep 10
    check_active_yoursite_wifi
    if $is_active_yoursite_wifi; then
      if $is_simple_mesh; then
        # 1 dongle
        _simplexmst_wifi_simplemesh_wpa
        ret=$?
      else
        # 0 dongle (Wi-Fi)
        _simplexmst_wifi_nomesh_hostapd
        ret=$?
      fi
    else
      if $is_simple_mesh; then
        # 1 dongle
        #connect_ether
        ret=0
      else
        # 0 dongle (Ethernet)
        connect_ether
        ret=$?
      fi
    fi
    if [ "$ret" -eq 0 ]; then
      if $is_active_yoursite_wifi; then
        if $is_simple_mesh; then
          # 1 dongle
          # hostapd #######################
          startup_hostapd_with_timeout /etc/rdbox/hostapd_ap_bg.conf /etc/rdbox/hostapd_be.conf
          ret=$?
          #################################
        else
          # 0 dongle (Wi-Fi)
          _simplexmst_wifi_nomesh_wpa
          ret=$?
        fi
      else
        if $is_simple_mesh; then
          # 1 dongle
          _simplexmst_ether_simplemesh_hostapd
          ret=$?
        else
          # 0 dongle (Ethernet)
          source /etc/rdbox/network/iptables.mstsimple.eth0
          sed -i -e '/^interface\=/c\interface\=wlan0' /etc/rdbox/hostapd_ap_bg.conf
          # hostapd #######################
          startup_hostapd_with_timeout /etc/rdbox/hostapd_ap_bg.conf
          ret=$?
          #################################
        fi
      fi
      if [ "$ret" -eq 0 ]; then
        break
      fi
    fi
    if [ $COUNT -eq $RETRY_COUNT ]; then
      echo "Master Process RETRY OVER!"
      return 1
    fi
    COUNT=$((COUNT + 1))
  done
  # Success Connection
  if $is_active_yoursite_wifi; then
    /sbin/brctl addif br0 eth0
  fi
  /sbin/brctl addif br0 bat0
  ip link set up dev bat0
  _ip_count=$(/sbin/ifconfig br0 | grep 'inet' | cut -d: -f2 | awk '{ print $2}' | wc -l)
  if [ "$_ip_count" -eq 0 ]; then
    if ! wait_dhclient br0; then
      return 1
    fi
  fi
  _ip_count=$(/sbin/ifconfig vpn_rdbox | grep 'inet' | cut -d: -f2 | awk '{ print $2}' | wc -l)
  if [ "$_ip_count" -eq 0 ]; then
    if ! wait_dhclient vpn_rdbox; then
      return 1
    fi
    ip link set vpn_rdbox mtu 1280
  fi
  update_dnsinfo
  return 0
}

for_simplexslv () {
  REGISTERD_WIFI_DEV=$(grep -o 'SUBSYSTEM' /etc/udev/rules.d/70-persistent-net.rules | wc -l)
  if [ "$REGISTERD_WIFI_DEV" -eq 2 ]; then
    /usr/sbin/hwinfo --wlan | /bin/grep "SysFS ID" | /bin/grep "usb" | /bin/sed -e 's/^[ ]*//g' | /usr/bin/awk '{print $3}' | /usr/bin/awk -F "/" '{ print $NF }' | /usr/bin/python /opt/rdbox/boot/rdbox-bind_unbind_dongles.py
  fi
  COUNT=0
  if ! check_device_simple; then
    /bin/echo "Do not found device!"
    return 2
  fi
  while true; do
    pkill -INT -f hostapd
    pkill -INT -f wpa_supplicant
    sleep 10
    # wpa_supplicant ##############
    if connect_wifi_with_timeout -i wlan0 -c /etc/rdbox/wpa_supplicant_be.conf; then
      # hostapd #######################
      sleep 10
      if startup_hostapd_with_timeout /etc/rdbox/hostapd_ap_bg.conf /etc/rdbox/hostapd_be.conf; then
        break
      fi
      sleep 10
    fi
    if [ $COUNT -eq $RETRY_COUNT ]; then
        echo "Slave Process RETRY OVER!"
        return 1
    fi
    COUNT=$((COUNT + 1))
  done
  # Success Connection
  if ! check_batman; then
    return 1
  fi

  if ! wait_dhclient br0; then
    return 1
  fi
  ip_br0_with_cidr=$(ip -f inet -o addr show br0|cut -d\  -f 7 | tr -d '\n')
  /sbin/brctl addif br0 eth0
  if ! check_active_default_gw; then
    /sbin/route add default gw "$(cidr_default_gw "$ip_br0_with_cidr")"
  fi
  return 0
}

bootup () {
  /bin/echo "$(date)" > $HOSTAPD_LOG
  /bin/echo "$(date)" > $WPA_LOG
  discrimination_model
  if ! wait_ssh; then
    /bin/echo "Do not work sshd!"
    exit 1
  fi
  ret=9
  if [[ $rdbox_type =~ $regex_simplexmst ]]; then
    for_simplexmst
    ret=$?
  elif [[ $rdbox_type =~ $regex_simplexslv ]]; then
    for_simplexslv
    ret=$?
  fi
  if [ "$ret" -gt 0 ]; then
    # led0 is green
    # led1 is red
    /bin/echo "Failure in constructing a mesh network."
    /bin/echo "Restart RDBOX after 10 minutes."
    /bin/echo "$(date)"
    echo none | tee /sys/class/leds/led0/trigger
    echo none | tee /sys/class/leds/led1/trigger
    echo 255 > /sys/class/leds/led0/brightness
    echo 0 > /sys/class/leds/led1/brightness
    sleep 1200
    /bin/echo "$(date)"
    reboot
  fi
}

# adv process
/bin/echo "Start!!"
/bin/echo "$(date)"
# Bootup hostapd and wpa_supplicant
bootup
# Post process
/bin/echo "Connected!!"
/bin/echo "$(date)"

exit 0