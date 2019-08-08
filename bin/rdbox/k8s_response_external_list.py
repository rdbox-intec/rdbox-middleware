#!/usr/bin/env python3
# coding: utf-8


class K8sResponseExternalList(object):
    def __init__(self, caller, resp_helper):
        self.caller = caller
        self.resp_helper = resp_helper
        self.org_response = None
        self.list = []

    def call(self):
        self.org_response = self.caller.call()
        self.resp_helper.set_input_data_list(self.org_response)
        # list[K8sResponseExternal]
        list_of_K8sResponseExternal = self.resp_helper.parse()
        for k8s_response_external in list_of_K8sResponseExternal:
            self.add(k8s_response_external)
        return self

    def add(self, response_external):
        self.list.append(response_external)
        return self

    def get_org_response(self):
        return self.org_response

    def get_external_list(self):
        return self.list
