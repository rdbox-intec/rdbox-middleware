#!/bin/bash
export LC_ALL=C
export LANG=C

WPA_LOG=/var/log/rdbox/rdbox_boot_wpa.log
PIDFILE_SUPLICANT=/run/wpa_supplicant.pid
RETRY_COUNT=5
WPA_AUTH_TIMEOUT=30

wait_dhclient () {
  sleep 10
  COUNT=0
  while true
  do
    if /sbin/dhclient -1 "$1"; then
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
    COUNT=$((COUNT + 1))
  done
  return 0
}

watch_wifi () {
  current_time=$1
  while read -rt ${WPA_AUTH_TIMEOUT} line; do
    echo "  $line"
    if echo "$line" | grep -wq 'CTRL-EVENT-CONNECTED'; then
      echo "  wifi OK!!"
      return 0
    fi
    # judge timeout
    if [ $(($(date +%s) - current_time)) -gt ${WPA_AUTH_TIMEOUT} ]; then
      echo "  unmatch Timeout."
      return 1
    fi
  done
  echo "  read Timeout."
  return 2
}

connect_wifi_with_timeout () {
  current_time=$(date +%s)
  /sbin/wpa_supplicant -B -f $WPA_LOG -P $PIDFILE_SUPLICANT -D nl80211 "$@"
  rtn=1
  { watch_wifi "$current_time"; rtn=$?; kill -s INT "$(pgrep -a tail | grep -v /usr/bin/timeout | grep $WPA_LOG | awk '{ print $1 }')"; } < <(/usr/bin/timeout --signal=HUP "$((WPA_AUTH_TIMEOUT + 10))"s /usr/bin/tail --follow=name --retry $WPA_LOG)
  if [ $rtn -eq 0 ]; then
    return 0
  else
    echo 'WPA authentication failed.'
    pkill -INT -f wpa_supplicant
    return 5
  fi
}

connect_ether () {
  _ip_count=$(/sbin/ifconfig eth0 | grep 'inet' | cut -d: -f2 | awk '{ print $2}' | wc -l)
  if [ "$_ip_count" -eq 0 ]; then
    if ! wait_dhclient eth0; then
      return 6
    fi
  fi
  return 0
}