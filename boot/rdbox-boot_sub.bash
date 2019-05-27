#!/bin/bash
export LC_ALL=C
export LANG=C

SSHD_TIMEOUT=120
WPA_AUTH_TIMEOUT=30
HOSTAPD_TIMEOUT=30
regex_master='^.*master.*'
regex_slave='^.*slave.*'
regex_simplexmst='^.*simplexmst.*'
regex_simplexslv='^.*simplexslv.*'
is_simple_mesh=false
hname=`/bin/hostname`
RETRY_COUNT=5
WPA_LOG=/var/log/rdbox/rdbox_boot_wpa.log
HOSTAPD_LOG=/var/log/rdbox/rdbox_boot_hostapd.log
PIDFILE_SUPLICANT=/var/run/wpa_supplicant.pid
PIDFILE_HOSTAPD=/var/run/hostapd.pid

wait_ssh () {
  COUNT=0
  while true
  do
    isAlive=`ps -ef | grep "/usr/sbin/sshd" | grep -v grep | wc -l`
    if [ $isAlive = 1 ]; then
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
    COUNT=`expr $COUNT + 1`
  done
  sleep 10
}

wait_dhclient () {
  COUNT=0
  checkBATMAN=`/usr/sbin/batctl if | grep -v grep | wc -l`
  if [ $checkBATMAN = 2 ]; then
      echo "BATMAN is running."
  else
      echo "BATMAN is Bad."
      return 10
  fi
  while true
  do
    /sbin/dhclient -4 br0
    if [ $? = 0 ]; then
      echo "dhclient is running."
      break
    else
      echo "wait dhclient..."
    fi
    if [ $COUNT -eq $RETRY_COUNT ]; then
      echo "dhclient RETRY OVER!"
      return 8
    fi
    sleep 10
    COUNT=`expr $COUNT + 1`
  done
}

check_device_full () {
  ifconfig eth0 > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "Device named 'eth0' not found."
    return 8
  fi
  iwconfig wlan0 > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "Device named 'wlan0' not found."
    return 8
  fi
  iwconfig wlan1 > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "Device named 'wlan1' not found."
    return 8
  fi
  iwconfig wlan2 > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "Device named 'wlan2' not found."
    return 8
  fi
  iwconfig wlan3 > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "Device named 'wlan3' not found."
    return 8
  fi
  iwconfig wlan10 > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "Device named 'wlan10' not found."
    return 8
  fi
  return 0
}

check_device_simple () {
  ifconfig eth0 > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "Device named 'eth0' not found."
    return 8
  fi
  iwconfig wlan10 > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "Device named 'wlan10' not found."
    return 8
  fi
  iwconfig wlan0 > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "Device named 'wlan0' not found."
    is_simple_mesh=false
  else
    echo "Enable simple mesh"
    is_simple_mesh=true
  fi
  return 0
}

watch_wifi () {
  current_time=$1
  while read -t ${WPA_AUTH_TIMEOUT} line; do
    echo "  $line"
    echo $line | grep -wq 'CTRL-EVENT-CONNECTED'
    if [ $? -eq 0 ]; then
      echo "  wifi OK!!"
      return 0
    fi
    # judge timeout
    if [ $(($(date +%s) - ${current_time})) -gt ${WPA_AUTH_TIMEOUT} ]; then
      echo "  unmatch Timeout."
      return 1
    fi
  done
  echo "  read Timeout."
  return 2
}

watch_hostapd () {
  current_time=$1
  while read -t ${HOSTAPD_TIMEOUT} line; do
    echo "  $line"
    echo $line | grep -wq 'AP-ENABLED'
    if [ $? -eq 0 ]; then
      echo "  hostapd OK!!"
      return 0
    fi
    # judge timeout
    if [ $(($(date +%s) - ${current_time})) -gt ${HOSTAPD_TIMEOUT} ]; then
      echo "  unmatch Timeout."
      return 1
    fi
  done 
  echo "  read Timeout."
  return 2
}

connect_wifi_with_timeout () {
  # wpa #######################
  current_time=$(date +%s)
  /sbin/wpa_supplicant -B -f $WPA_LOG -P $PIDFILE_SUPLICANT -D nl80211 $@
  rtn=1
  { watch_wifi $current_time; rtn=$?; kill -s INT `ps -e -o pid,cmd | grep /usr/bin/tail | grep -v /usr/bin/timeout | grep $WPA_LOG | grep -v grep | awk '{ print $1 }'`; } < <(/usr/bin/timeout --signal=HUP `expr $WPA_AUTH_TIMEOUT + 10`s /usr/bin/tail -n 0 --follow=name --retry $WPA_LOG) 
  if [ $rtn -eq 0 ]; then
    return 0
  else
    echo 'WPA authentication failed.'
    pkill -INT -f wpa_supplicant
    return 5
  fi
}

startup_hostapd_with_timeout () {
  # hostapd #######################
  current_time=$(date +%s)
  /usr/sbin/hostapd -B -f $HOSTAPD_LOG -P $PIDFILE_HOSTAPD $@
  rtn=1
  { watch_hostapd $current_time; rtn=$?; kill -s INT `ps -e -o pid,cmd | grep /usr/bin/tail | grep -v /usr/bin/timeout | grep $HOSTAPD_LOG | grep -v grep | awk '{ print $1 }'`; } < <(exec /usr/bin/timeout --signal=HUP `expr $HOSTAPD_TIMEOUT + 10`s /usr/bin/tail -n 0 --follow=name --retry $HOSTAPD_LOG)
  if [ $rtn -eq 0 ]; then
    return 0
  else
    echo 'hostapd startup failed.'
    pkill -INT -f hostapd
    return 6
  fi
}

for_master () {
  COUNT=0
  check_device_full
  if [ $? -gt 0 ]; then
    /bin/echo "Do not check device!"
    return 2
  fi
  while true; do
    pkill -INT -f hostapd
    pkill -INT -f wpa_supplicant
    sleep 10
    # hostapd #######################
    startup_hostapd_with_timeout /etc/rdbox/hostapd_be.conf /etc/rdbox/hostapd_ap_an.conf /etc/rdbox/hostapd_ap_bg.conf
    if [ $? -eq 0 ]; then
      # wpa_supplicant ##############
      sleep 10
      connect_wifi_with_timeout -i wlan0 -c /etc/rdbox/wpa_supplicant_be.conf
      if [ $? -eq 0 ]; then
        break
      fi
      sleep 10
    fi
    if [ $COUNT -eq $RETRY_COUNT ]; then
      echo "Master Process RETRY OVER!"
      return 1
    fi
    COUNT=`expr $COUNT + 1`
  done
  return 0
}

for_slave () {
  COUNT=0
  check_device_full
  if [ $? -gt 0 ]; then
    /bin/echo "Do not check device!"
    return 2
  fi
  while true; do
    pkill -INT -f hostapd
    pkill -INT -f wpa_supplicant
    sleep 10
    # wpa_supplicant ##############
    connect_wifi_with_timeout -i wlan0 -c /etc/rdbox/wpa_supplicant_be.conf
    if [ $? -eq 0 ]; then
      # hostapd #######################
      sleep 10
      startup_hostapd_with_timeout /etc/rdbox/hostapd_be.conf /etc/rdbox/hostapd_ap_an.conf /etc/rdbox/hostapd_ap_bg.conf
      if [ $? -eq 0 ]; then
        break
      fi
      sleep 10
    fi
    if [ $COUNT -eq $RETRY_COUNT ]; then
        echo "Slave Process RETRY OVER!"
        return 1
    fi
    COUNT=`expr $COUNT + 1`
  done
  # Success Connection
  wait_dhclient
  if [ $? -gt 0 ]; then
    return 1
  fi
  /sbin/brctl addif br0 eth0
  return 0
}

for_simplexmst () {
  REGISTERD_WIFI_DEV=`grep -o 'SUBSYSTEM' /etc/udev/rules.d/70-persistent-net.rules | wc -l`
  if [ $REGISTERD_WIFI_DEV -eq 2 ]; then
    /usr/sbin/hwinfo --wlan | /bin/grep "SysFS ID" | /bin/grep "usb" | /bin/sed -e 's/^[ ]*//g' | /usr/bin/awk '{print $3}' | /usr/bin/awk -F "/" '{ print $NF }' | /usr/bin/python /opt/rdbox/boot/rdbox-bind_unbind_dongles.py
  fi
  COUNT=0
  check_device_simple
  if [ $? -gt 0 ]; then
    /bin/echo "Do not check device!"
    return 2
  fi
  while true; do
    pkill -INT -f hostapd
    pkill -INT -f wpa_supplicant
    sleep 10
    # hostapd #######################
    if $is_simple_mesh; then
      startup_hostapd_with_timeout /etc/rdbox/hostapd_ap_bg.conf /etc/rdbox/hostapd_be.conf
    else
      startup_hostapd_with_timeout /etc/rdbox/hostapd_ap_bg.conf
    fi
    if [ $? -eq 0 ]; then
      break
    fi
    if [ $COUNT -eq $RETRY_COUNT ]; then
      echo "Master Process RETRY OVER!"
      return 1
    fi
    COUNT=`expr $COUNT + 1`
  done
  # Success Connection
  cp $PIDFILE_HOSTAPD $PIDFILE_SUPLICANT
  /sbin/brctl addif br0 tap_tap0
  return 0
}

for_simplexslv () {
  REGISTERD_WIFI_DEV=`grep -o 'SUBSYSTEM' /etc/udev/rules.d/70-persistent-net.rules | wc -l`
  if [ $REGISTERD_WIFI_DEV -eq 2 ]; then
    /usr/sbin/hwinfo --wlan | /bin/grep "SysFS ID" | /bin/grep "usb" | /bin/sed -e 's/^[ ]*//g' | /usr/bin/awk '{print $3}' | /usr/bin/awk -F "/" '{ print $NF }' | /usr/bin/python /opt/rdbox/boot/rdbox-bind_unbind_dongles.py
  fi
  COUNT=0
  check_device_simple
  if [ $? -gt 0 ]; then
    /bin/echo "Do not check device!"
    return 2
  fi
  while true; do
    pkill -INT -f hostapd
    pkill -INT -f wpa_supplicant
    sleep 10
    # wpa_supplicant ##############
    connect_wifi_with_timeout -i wlan10 -c /etc/rdbox/wpa_supplicant_be.conf
    if [ $? -eq 0 ]; then
      # hostapd #######################
      sleep 10
      startup_hostapd_with_timeout /etc/rdbox/hostapd_ap_bg.conf /etc/rdbox/hostapd_be.conf
      if [ $? -eq 0 ]; then
        break
      fi
      sleep 10
    fi
    if [ $COUNT -eq $RETRY_COUNT ]; then
        echo "Slave Process RETRY OVER!"
        return 1
    fi
    COUNT=`expr $COUNT + 1`
  done
  # Success Connection
  wait_dhclient
  if [ $? -gt 0 ]; then
    return 1
  fi
  /sbin/brctl addif br0 eth0
  return 0
}

bootup () {
  /bin/echo `date` > $HOSTAPD_LOG
  /bin/echo `date` > $WPA_LOG
  wait_ssh
  if [ $? -gt 0 ]; then
    /bin/echo "Do not work sshd!"
    exit 1
  fi
  if [[ $hname =~ $regex_master ]]; then
    for_master
  elif [[ $hname =~ $regex_slave ]]; then
    for_slave
  elif [[ $hname =~ $regex_simplexmst ]]; then
    for_simplexmst
  elif [[ $hname =~ $regex_simplexslv ]]; then
    for_simplexslv
  fi
  if [ $? -gt 0 ]; then
    # led0 is green
    # led1 is red
    /bin/echo "Failure in constructing a mesh network."
    /bin/echo "Restart RDBOX after 10 minutes."
    echo none | tee /sys/class/leds/led0/trigger
    echo none | tee /sys/class/leds/led1/trigger
    echo 255 > /sys/class/leds/led0/brightness
    echo 0 > /sys/class/leds/led1/brightness
    sleep 1200
    reboot
  fi
}

# Bootup hostapd and wpa_supplicant
bootup
# Post process
/bin/echo "Connected!!"

exit 0
