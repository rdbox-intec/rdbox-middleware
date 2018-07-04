#!/bin/bash

LIMIT_PING_COUNT=21600 # about 12h(6h*2)
SUCCESS_THRESHOLD=15

if [ $# -ne 5 ]; then
  echo "invalid args."
  exit 1
fi

IP_K8S_MASTER=`echo $1| cut -d ":" -f 1`
count=0
success=0
while :
do
  count=`expr $count + 1`
  sudo ping -w 1 -n -c 1 $IP_K8S_MASTER  >> /dev/null
  if [ $? -eq 0 ]
  then
    echo $(date +%H:%M:%S:%N) "+++ OK +++"
    success=`expr $success + 1`
    if [ $success -eq $SUCCESS_THRESHOLD ]; then
      sudo kubeadm join "$@"
      exit 0
    fi
    sleep 1
  else
    echo $(date +%H:%M:%S:%N) "+++ NG +++"
    success=0
    sleep 1
  fi
  if [ $count -eq $LIMIT_PING_COUNT ]; then
    echo $(date +%H:%M:%S:%N) "+++ COUNT OVER +++"
    exit 2
  fi
done
