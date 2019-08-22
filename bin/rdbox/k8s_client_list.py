#!/usr/bin/env python3
# coding: utf-8

from rdbox.k8s_client import K8sClient
from rdbox.input_data_list import InputDataList


class K8sClientList(object):

    def __init__(self):
        self.client_list = []

    def add(self, client):
        if isinstance(client, K8sClient):
            self.client_list.append(client)
        return self

    def call(self):
        input_data_list = InputDataList()
        for client in self.client_list:
            ret = client.call()
            input_data_list.add(ret)
        return input_data_list
