#!/bin/bash
export LC_ALL=C
export LANG=C

regex_master='^.*master.*'
regex_slave='^.*slave.*'
regex_vpnbridge='^.*vpnbridge.*'
regex_simplexmst='^.*simplexmst.*'
regex_simplexslv='^.*simplexslv.*'
hname=`/bin/hostname`

echo $$ > /var/lib/rdbox/.completed_first_session

/bin/bash /opt/rdbox/boot/rdbox-first_session_sub.bash >> /var/log/rdbox/rdbox_first_session.log 2>&1

if [[ $hname =~ $regex_master ]]; then
  echo "master" > /var/lib/rdbox/.completed_first_session
elif [[ $hname =~ $regex_slave ]]; then
  echo "slave" > /var/lib/rdbox/.completed_first_session
elif [[ $hname =~ $regex_vpnbridge ]]; then
  echo "vpnbridge" > /var/lib/rdbox/.completed_first_session
elif [[ $hname =~ $regex_simplexmst ]]; then
  echo "simplexmst" > /var/lib/rdbox/.completed_first_session
elif [[ $hname =~ $regex_simplexslv ]]; then
  echo "simplexslv" > /var/lib/rdbox/.completed_first_session
else
  echo "other" > /var/lib/rdbox/.completed_first_session
fi

exit 0
