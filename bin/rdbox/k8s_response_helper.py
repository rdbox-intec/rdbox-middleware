#!/usr/bin/env python3
# coding: utf-8

class K8sResponseHelper(object):

    LOCATION_NOT_DEFINE = "NOT_DEFINE"
    NGINX_INGRESS_SUFFIX = "nginx-ingress-controller"

    def __init__(self):
        self.input_data_list = None

    def set_input_data_list(self, input_data_list):
        """
        :return: K8sResponseHelper
        """
        self.input_data_list = input_data_list
        return self

    def get_input_data_list(self):
        """
        :return: InputDataList[kubernetes/client/models/*]
        """
        return self.input_data_list

    def parse(self):
        """
        Parse InputDataList[kubernetes/client/models/*] to list[K8sResponseExternal].
            InputDataList[kubernetes/client/models/*] set by K8sResponseHelper.set_input_data_list()
            Execute From K8sResponseExternalList.call()
        :return: list[K8sResponseExternal]
        """
        assert False
        
