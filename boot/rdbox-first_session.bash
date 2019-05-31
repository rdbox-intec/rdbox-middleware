#!/bin/bash
export LC_ALL=C
export LANG=C

regex_master='^.*master.*'
regex_slave='^.*slave.*'
regex_vpnbridge='^.*vpnbridge.*'
regex_simplexmst='^.*simplexmst.*'
regex_simplexslv='^.*simplexslv.*'
hname=`/bin/hostname`
is_simple=`cat /var/lib/rdbox/.is_simple`
if [ $? -ne 0 ]; then
  is_simple=false
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

echo $$ > /var/lib/rdbox/.completed_first_session

/bin/bash /opt/rdbox/boot/rdbox-first_session_sub.bash >> /var/log/rdbox/rdbox_first_session.log 2>&1

if [[ $rdbox_type =~ $regex_master ]]; then
  echo "master" > /var/lib/rdbox/.completed_first_session
elif [[ $rdbox_type =~ $regex_slave ]]; then
  echo "slave" > /var/lib/rdbox/.completed_first_session
elif [[ $rdbox_type =~ $regex_vpnbridge ]]; then
  echo "vpnbridge" > /var/lib/rdbox/.completed_first_session
elif [[ $rdbox_type =~ $regex_simplexmst ]]; then
  echo "simplexmst" > /var/lib/rdbox/.completed_first_session
elif [[ $rdbox_type =~ $regex_simplexslv ]]; then
  echo "simplexslv" > /var/lib/rdbox/.completed_first_session
else
  echo "other" > /var/lib/rdbox/.completed_first_session
fi

exit 0
