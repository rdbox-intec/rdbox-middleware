#!/usr/bin/env python3
# coding: utf-8

from rdbox.k8s_client import K8sClient
from kubernetes import client, config


class K8sClientCoreV1Api(K8sClient):
    def __init__(self, method_name, opt=None):
        if opt is None:
            self.opt = {}
        else:
            self.opt = opt
        self.method_name = method_name

    def call(self):
        config.load_kube_config(K8sClient.CONF_FILEPATH)
        v1 = client.CoreV1Api()
        ret = getattr(v1, self.method_name)(**self.opt)
        return ret
