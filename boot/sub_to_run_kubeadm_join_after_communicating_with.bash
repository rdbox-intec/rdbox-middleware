#!/bin/bash
export LC_ALL=C
export LANG=C

remote_user='ubuntu'

regex_master='^.*master.*'
regex_slave='^.*slave.*'
rdbox_type="other"
hname=$(/bin/hostname)

LIMIT_PING_COUNT=21600 # about 12h(6h*2)
SUCCESS_THRESHOLD=15

if [[ $hname =~ $regex_master ]]; then
  rdbox_type="master"
elif [[ $hname =~ $regex_slave ]]; then
  rdbox_type="slave"
else
  rdbox_type="other"
fi

IP_K8S_MASTER=$(echo "$1"| cut -d ":" -f 1)
count=0
success=0
while :
do
  count=$((count + 1))
  if sudo ping -w 1 -n -c 1 "$IP_K8S_MASTER"  >> /dev/null; then
    echo "$(date +%H:%M:%S:%N) +++ OK +++"
    success=$((success + 1))
    if [ "$success" -eq $SUCCESS_THRESHOLD ]; then
      sudo kubeadm join "$@"
      mkdir -p /home/"$(ls /home)"/.kube/
      scp -o "StrictHostKeyChecking=no" $remote_user@"$IP_K8S_MASTER":/home/$remote_user/.kube/config /home/"$(ls /home)"/.kube/config
      sleep 30
      kubectl label node "$(hostname)" node.rdbox.com/location=edge
      kubectl label node "$(hostname)" node.rdbox.com/edge=$rdbox_type
      exit 0
    fi
    sleep 1
  else
    echo "$(date +%H:%M:%S:%N) +++ NG +++"
    success=0
    sleep 1
  fi
  if [ $count -eq $LIMIT_PING_COUNT ]; then
    echo "$(date +%H:%M:%S:%N) +++ COUNT OVER +++"
    exit 2
  fi
done
