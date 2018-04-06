# coding: utf-8

import sys
import csv
from itertools import islice
import subprocess
import time

SYSTEM_BUS_PORT="1-1." # FOR RaspberryPi

def main():
    rows, header = csv_read_stdin(1000, False)
    top_hub = header[0]
    for row in [1, 2, 4, 3]:
        port = SYSTEM_BUS_PORT + top_hub + "." + str(row)
        cmd = 'echo -n "%s" > /sys/bus/usb/drivers/usb/unbind' % port
        subprocess.call(cmd, shell=True)
    for row in [1, 2, 4, 3]:
        port = SYSTEM_BUS_PORT + top_hub + "." + str(row)
        cmd = 'echo -n "%s" > /sys/bus/usb/drivers/usb/bind' % port
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
