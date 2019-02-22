#!/usr/bin/env python3
# coding: utf-8

from rdbox.k8s_response_helper import K8sResponseHelper
from rdbox.rdbox_node_formatter import RdboxNodeFormatter

from logging import getLogger, StreamHandler, Formatter
r_logger = getLogger('rdbox_cli')
r_print = getLogger('rdbox_cli').getChild("stdout")

class AnsibleRdboxNodeFormatter(RdboxNodeFormatter):
    def output_report(self, rdbox_node_list):
        output_str = ""
        grouping_dict = rdbox_node_list.group_by("location")
        longest_number = rdbox_node_list.get_longest_number_of_char_for("hostname")
        longest_number_ip = rdbox_node_list.get_longest_number_of_char_for("ip")
        if K8sResponseHelper.LOCATION_NOT_DEFINE in grouping_dict:
            for rdbox_node in grouping_dict.get(K8sResponseHelper.LOCATION_NOT_DEFINE):
                space = self._get_prety_string(rdbox_node.get_hostname(), longest_number)
                space_ip = self._get_prety_string(rdbox_node.get_ip(), longest_number_ip)
                output_str += "%s%s  ansible_host=%s%s  ansible_python_interpreter=/usr/bin/python3\n" % (rdbox_node.get_hostname(), space, rdbox_node.get_ip(), space_ip)
            output_str += "\n"

        for key, list_of_group in grouping_dict.items():
            if key != K8sResponseHelper.LOCATION_NOT_DEFINE:
                output_str += "[%s]\n" % (key)
            else:
                continue
            for rdbox_node in list_of_group:
                space = self._get_prety_string(rdbox_node.get_hostname(), longest_number)
                space_ip = self._get_prety_string(rdbox_node.get_ip(), longest_number_ip)
                output_str += "%s%s  ansible_host=%s%s  ansible_python_interpreter=/usr/bin/python3\n" % (rdbox_node.get_hostname(), space, rdbox_node.get_ip(), space_ip)
            output_str += "\n"
        r_print.info(output_str)
        return rdbox_node_list, output_str

    def _get_prety_string(self, before_string, max_width, prety_str=" "):
        return prety_str * (max_width - len(before_string))
