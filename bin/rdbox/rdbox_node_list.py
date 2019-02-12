#!/usr/bin/env python3
# coding: utf-8

from rdbox.rdbox_node import RdboxNode

class RdboxNodeList(object):
    def __init__(self, k8s_external_list):
        self.list = self.to_RdboxNodeList(k8s_external_list)

    def to_RdboxNodeList(self, k8s_external_list):
        l = k8s_external_list.get_external_list()
        tmp = []
        for external in l:
            hostname = external.get_hostname()
            ip = external.get_ip()
            location = external.get_location()
            rdb_node = RdboxNode(hostname, ip, location)
            tmp.append(rdb_node)
        return tmp

    def set_from_list(self, in_data):
        for data in in_data:
            self.list.append(data)

    def get_by_list(self):
        return self.list

    def group_by(self, member_name):
        group_by_member_dict = {}
        from rdbox.k8s_response_helper import K8sResponseHelper
        for rdbox_node in self.list:
            group_key = getattr(rdbox_node, member_name, K8sResponseHelper.LOCATION_NOT_DEFINE)
            if group_key in group_by_member_dict:
                group_by_member_dict[group_key].append(rdbox_node)
            else:
                group_by_member_dict[group_key] = []
                group_by_member_dict[group_key].append(rdbox_node)
        return group_by_member_dict


    def get_longest_number_of_char_for(self, member_name):
        number = 0
        for rdbox_node in self.list:
            this_length = len(getattr(rdbox_node, member_name, "A"))
            if this_length > number:
                number = this_length
        return number
