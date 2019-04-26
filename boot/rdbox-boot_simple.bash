#!/bin/bash
export LC_ALL=C
export LANG=C

SSHD_TIMEOUT=120
WPA_AUTH_TIMEOUT=30
HOSTAPD_TIMEOUT=30
RETRY_COUNT=5
regex_simplexmst='^.*simplexmst.*'
regex_simplexslv='^.*simplexslv.*'

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
  iwconfig wlan10 > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "Device named 'wlan10' not found."
    return 8
  fi
  return 0
}

bootup() {
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
  if [[ $hname =~ $regex_simplexmst ]]; then
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
