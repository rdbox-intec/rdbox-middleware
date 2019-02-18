#!/bin/bash

regex_master='^.*master.*'
regex_slave='^.*slave.*'
regex_vpnbridge='^.*vpnbridge.*'
hname=`/bin/hostname`

echo "processing" > /var/lib/rdbox/.completed_first_session

/bin/bash /opt/rdbox/boot/rdbox-first_session_sub.bash /var/log/rdbox_first_session.log 2>&1

if [[ $hname =~ $regex_master ]]; then
  echo "master" > /var/lib/rdbox/.completed_first_session
elif [[ $hname =~ $regex_slave ]]; then
  echo "slave" > /var/lib/rdbox/.completed_first_session
elif [[ $hname =~ $regex_vpnbridge ]]; then
  echo "vpnbridge" > /var/lib/rdbox/.completed_first_session
else
  echo "other" > /var/lib/rdbox/.completed_first_session
fi

exit 0
