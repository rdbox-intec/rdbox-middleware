#!/usr/bin/env python3
# coding: utf-8

import os


class K8sClient(object):
    USER = os.environ['SUDO_USER'] if 'SUDO_USER' in os.environ else os.environ['USER']
    CONF_FILEPATH = "/home/{user}/.kube/config".format(user=USER)

    @classmethod
    def call(self):
        assert False
