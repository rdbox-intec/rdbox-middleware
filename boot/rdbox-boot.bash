#!/bin/bash
export LC_ALL=C
export LANG=C

regex_master='^.*master.*'
regex_slave='^.*slave.*'
regex_vpnbridge='^.*vpnbridge.*'
regex_simplexmst='^.*simplexmst.*'
regex_simplexslv='^.*simplexslv.*'
regex_other='^.*other.*'
hname=`/bin/hostname`
PIDFILE_SUPLICANT=/var/run/wpa_supplicant.pid
PIDFILE_HOSTAPD=/var/run/hostapd.pid
BOOT_LOG=/var/log/rdbox/rdbox_boot.log
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

hups () {
        PID=$1
        kill -SIGINT $PID
        #
        #       Now we have to wait until transproxy has _really_ stopped.
        #
        sleep 5
        if test -n "$PID" && kill -0 $PID 2>/dev/null
        then
                cnt=0
                while kill -0 $PID 2>/dev/null
                do
                        cnt=`expr $cnt + 1`
                        if [ $cnt -gt 24 ]
                        then
                                return 1
                        fi
                        sleep 5
                done
                return 0
        else
                return 0
        fi
}

start () {
	first_session_status=`cat /var/lib/rdbox/.completed_first_session`
        kill -0 $first_session_status > /dev/null 2>&1
	if [ $? = 0 ]; then
		if [[ $rdbox_type =~ $regex_master ]]; then
		  source /etc/rdbox/network/iptables > $BOOT_LOG 2>&1
		  /bin/bash /opt/rdbox/boot/rdbox-boot_sub.bash >> $BOOT_LOG 2>&1
		elif [[ $rdbox_type =~ $regex_slave ]]; then
		  /bin/bash /opt/rdbox/boot/rdbox-boot_sub.bash > $BOOT_LOG 2>&1
		elif [[ $rdbox_type =~ $regex_simplexmst ]]; then
		  /bin/bash /opt/rdbox/boot/rdbox-boot_sub.bash >> $BOOT_LOG 2>&1
		elif [[ $rdbox_type =~ $regex_simplexslv ]]; then
		  /bin/bash /opt/rdbox/boot/rdbox-boot_sub.bash > $BOOT_LOG 2>&1
		else
		  echo "OK!!"
		fi
	else
    all_status_reg="$regex_master|$regex_slave|$regex_vpnbridge|$regex_other|$regex_simplexmst|$regex_simplexslv"
		if [[ $first_session_status =~ $all_status_reg ]]; then
			echo "Finished First Session."
		else
			# RETRY ######################
			source /opt/rdbox/boot/rdbox-first_session.bash
			##############################
		fi
		if [[ $rdbox_type =~ $regex_master ]]; then
		  source /etc/rdbox/network/iptables > $BOOT_LOG 2>&1
		  /bin/bash /opt/rdbox/boot/rdbox-boot_sub.bash >> $BOOT_LOG 2>&1
		elif [[ $rdbox_type =~ $regex_slave ]]; then
		  /bin/bash /opt/rdbox/boot/rdbox-boot_sub.bash > $BOOT_LOG 2>&1
		elif [[ $rdbox_type =~ $regex_simplexmst ]]; then
		  /bin/bash /opt/rdbox/boot/rdbox-boot_sub.bash >> $BOOT_LOG 2>&1
		elif [[ $rdbox_type =~ $regex_simplexslv ]]; then
		  /bin/bash /opt/rdbox/boot/rdbox-boot_sub.bash > $BOOT_LOG 2>&1
		else
		  echo "OK!!"
		fi
	fi
	return 0
}

stop () {
	hups `cat $PIDFILE_SUPLICANT 2>/dev/null`
	hups `cat $PIDFILE_HOSTAPD 2>/dev/null`
	return $?
}

case "$1" in
    start)
        if start ; then
                echo "OK!"
        else
                echo "NG!"
        fi
        ;;
    stop)
        if stop ; then
                echo "OK!"
        else
                echo "NG!"
        fi
        ;;
    *)
        echo "Usage: ./$NAME {start|stop}"
        exit 3
        ;;
esac

exit 0
