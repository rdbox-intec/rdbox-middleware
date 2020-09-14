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

# Step1 Specify the network interface for master.
if [[ $rdbox_type = "master" ]]; then
  ip_br0=$(ip -f inet -o addr show br0|cut -d\  -f 7 | cut -d/ -f 1 | tr -d '\n')
  echo "KUBELET_EXTRA_ARGS=--node-ip=${ip_br0}" > /etc/default/kubelet
  sudo systemctl daemon-reload
  sudo systemctl restart kubelet.service
  sleep 10
fi

# Step2 Issue join command
while :
do
  count=$((count + 1))
  if sudo ping -w 1 -n -c 1 "$IP_K8S_MASTER"  >> /dev/null; then
    echo "$(date +%H:%M:%S:%N) +++ OK +++"
    success=$((success + 1))
    if [ "$success" -eq $SUCCESS_THRESHOLD ]; then
      sudo kubeadm join "$@"
      mkdir -p /home/$remote_user/.kube/
      scp -i /home/$remote_user/.ssh/id_rsa -o "StrictHostKeyChecking=no" $remote_user@"$IP_K8S_MASTER":/home/$remote_user/.kube/config /home/$remote_user/.kube/config
      chown $remote_user:$remote_user /home/$remote_user/.kube/config
      sleep 15
      kubectl label node "$(hostname)" node.rdbox.com/location=edge --kubeconfig /home/$remote_user/.kube/config
      kubectl label node "$(hostname)" node.rdbox.com/edge=$rdbox_type --kubeconfig /home/$remote_user/.kube/config
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
