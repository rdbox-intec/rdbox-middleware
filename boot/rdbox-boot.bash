#!/bin/bash

regex_master='^.*master.*'
regex_slave='^.*slave.*'
regex_vpnbridge='^.*vpnbridge.*'
hname=`/bin/hostname`
PIDFILE_SUPLICANT=/var/run/wpa_supplicant.wlan0.pid
PIDFILE_HOSTAPD=/var/run/hostapd.pid

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
	if [[ $hname =~ $regex_master ]]; then
	  source /etc/rdbox/network/iptables > /var/log/rdbox_boot.log 2>&1
	  /bin/bash /opt/rdbox/boot/rdbox-boot_sub.bash >> /var/log/rdbox_boot.log 2>&1
	elif [[ $hname =~ $regex_slave ]]; then
	  /bin/bash /opt/rdbox/boot/rdbox-boot_sub.bash > /var/log/rdbox_boot.log 2>&1
	else
	  echo "OK!!"
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
