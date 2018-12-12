#!/bin/bash
export LC_ALL=C
export LANG=C

SSHD_TIMEOUT=120
WPA_AUTH_TIMEOUT=30
HOSTAPD_TIMEOUT=30
regex_master='^.*master.*'
regex_slave='^.*slave.*'
hname=`/bin/hostname`
USER=roboticist
PORT=12810
RETRY_COUNT=5
WPA_LOG=/var/log/rdbox_boot_wpa.log
HOSTAPD_LOG=/var/log/rdbox_boot_hostapd.log

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

check_device () {
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


connect_wifi_with_timeout () {
  # wpa #######################
  current_time=$(date +%s)
  /sbin/wpa_supplicant -B -f $WPA_LOG -P /var/run/wpa_supplicant.wlan0.pid -i wlan0 -D nl80211 -c /etc/rdbox/wpa_supplicant_be.conf
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

watch_hostapd () {
  current_time=$1
  while read -t ${HOSTAPD_TIMEOUT} line; do
    echo "  $line"
    echo $line | grep -wq 'wlan1: AP-ENABLED'
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

startup_hostapd_with_timeout () {
  # hostapd #######################
  current_time=$(date +%s)
  /usr/sbin/hostapd -B -f $HOSTAPD_LOG -P /var/run/hostapd.pid /etc/rdbox/hostapd_be.conf /etc/rdbox/hostapd_ap_an.conf /etc/rdbox/hostapd_ap_bg.conf
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
  while true; do
    pkill -INT -f hostapd
    pkill -INT -f wpa_supplicant
    sleep 10
    # hostapd #######################
    startup_hostapd_with_timeout
    if [ $? -eq 0 ]; then
      # wpa_supplicant ##############
      sleep 10
      connect_wifi_with_timeout
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
  while true; do
    pkill -INT -f hostapd
    pkill -INT -f wpa_supplicant
    sleep 10
    # wpa_supplicant ##############
    connect_wifi_with_timeout
    if [ $? -eq 0 ]; then
      # hostapd #######################
      sleep 10
      startup_hostapd_with_timeout
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
  sleep 10
  /sbin/dhclient br0
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
  check_device
  if [ $? -gt 0 ]; then
    /bin/echo "Do not check device!"
    exit 2
  fi
  if [[ $hname =~ $regex_master ]]; then
    for_master
  elif [[ $hname =~ $regex_slave ]]; then
    for_slave
  fi
  if [ $? -gt 0 ]; then
    echo heartbeat | tee /sys/class/leds/led0/trigger
    sleep 30
    reboot
  fi
}

# Bootup hostapd and wpa_supplicant
bootup
# Post process
/bin/echo "Connected!!"

exit 0
