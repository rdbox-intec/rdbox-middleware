#!/usr/bin/env python
# coding: utf-8

import sys
import csv
from itertools import islice
import subprocess
import time
import difflib

def main():
    rows, header = csv_read_stdin(1000, True)
    datas = []
    for row in rows:
        datas.append(row)
    mac_cmd = 'ip addr show | grep link/ether | sed -E "s@.*link/ether\s(\S+)(\s.*|$)@\\1@g"'
    mac_dict = {}
    mac_str = subprocess.check_output(mac_cmd, stderr=subprocess.STDOUT, shell=True)
    mac_str = mac_str.rstrip()
    mac_all = mac_str.splitlines()
    mac_set_before = set(mac_all)
    for i, row in enumerate(datas):
        i = i + 1
        port = row[0].split(":")[0][:-2] + ".%s" % str(i)
        cmd = 'echo -n "%s" > /sys/bus/usb/drivers/usb/unbind' % port
        print cmd
        subprocess.call(cmd, shell=True)
        mac_str = subprocess.check_output('ip addr show | grep link/ether | sed -E "s@.*link/ether\s(\S+)(\s.*|$)@\\1@g"', shell=True)
        mac_str = mac_str.rstrip()
        mac_all = mac_str.splitlines()
        mac_set = set(mac_all)
        diff = mac_set_before.symmetric_difference(mac_set)
        current_mac_addr = diff.pop()
        mac_dict.update({i: current_mac_addr})
        #--------
        mac_set_before = set(mac_all)
    rules = ""
    for index,addr in mac_dict.items():
        rule = 'SUBSYSTEM=="net", ACTION=="add", DRIVERS=="?*", ATTR{address}=="%s", ATTR{dev_id}=="0x0", ATTR{type}=="1", KERNEL=="wlan*", NAME="wlan%s"' % (addr, index - 1)
        rules = rules + rule + '\n'
    append_cmd = "echo '%s' >> /etc/udev/rules.d/70-persistent-net.rules" % rules
    print append_cmd
    subprocess.call(append_cmd, shell=True)
    for i, row in enumerate(datas):
        i = i + 1
        port = row[0].split(":")[0][:-2] + ".%s" % str(i)
        cmd = 'echo -n "%s" > /sys/bus/usb/drivers/usb/bind' % port
        print cmd
        subprocess.call(cmd, shell=True)
    print "Success USB BIND and UNBIND!!"


def csv_read_stdin(number, is_headerless):
    if sys.stdin.isatty():
        sys.stderr.write("Error")
        exit()
    reader = csv.reader(sys.stdin)
    header = [] if is_headerless else next(reader)
    rows = islice(reader, number)
    return rows, header

if __name__ == "__main__":
    main()
