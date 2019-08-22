#!/usr/bin/env python3
# coding: utf-8

from rdbox.rdbox_node_formatter import RdboxNodeFormatter
import socket

from logging import getLogger
r_logger = getLogger('rdbox_cli')
r_print = getLogger('rdbox_cli').getChild("stdout")


class EtchostsRdboxNodeFormatter(RdboxNodeFormatter):
    def output_report(self, rdbox_node_list):
        output_str = ""
        raw_list = rdbox_node_list.get_by_list()
        last_index = len(raw_list) - 1
        for i, rdbox_node in enumerate(raw_list):
            if i == last_index:
                output_str += "%s %s %s" % (rdbox_node.get_ip(
                ), rdbox_node.get_hostname(), self._get_fqdn(rdbox_node.get_hostname()))
            else:
                output_str += "%s %s %s\n" % (rdbox_node.get_ip(
                ), rdbox_node.get_hostname(), self._get_fqdn(rdbox_node.get_hostname()))
        r_print.info(output_str)
        return rdbox_node_list, output_str

    def _get_fqdn(self, hostname):
        return "%s.%s" % (hostname, socket.getaddrinfo(socket.gethostname(), 0, flags=socket.AI_CANONNAME)[0][3])
