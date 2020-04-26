#!/usr/bin/env python3
# coding: utf-8

import socket
from rdbox.k8s_response_helper import K8sResponseHelper
from rdbox.k8s_response_helper_v1servicelist import K8sResponseHelperV1ServiceList
from rdbox.k8s_response_external import K8sResponseExternal
from kubernetes.client.models import ExtensionsV1beta1IngressList, V1ServiceList


class K8sResponseHelperV1beta1IngressList(K8sResponseHelper):

    def parse(self):
        """
        Parse InputDataList[kubernetes/client/models/*] to list[K8sResponseExternal].
            InputDataList[kubernetes/client/models/*] set by K8sResponseHelper.set_input_data_list()
            Execute From K8sResponseExternalList.call()
        :return: list[K8sResponseExternal]
        """
        # ret
        ret = []  # list[K8sResponseExternal]
        # Service
        v1svc_input_data_list = self.get_input_data_list(
        ).get_by_instance(V1ServiceList)  # InputDataList
        helper_v1svc = K8sResponseHelperV1ServiceList()
        list_of_k8s_response_external = helper_v1svc.set_input_data_list(
            v1svc_input_data_list).parse()                  # list[K8sResponseExternal]
        list_of_nginx_ingress_external = self._get_nginx_ingress_external_list(
            list_of_k8s_response_external)               # list[K8sResponseExternal]
        list_of_ignore_nginx_ingress_external = self._get_ignore_nginx_ingress_external_list(
            list_of_k8s_response_external)  # list[K8sResponseExternal]
        # Ingress:
        v1ing_input_data_list = self.get_input_data_list().get_by_instance(
            ExtensionsV1beta1IngressList)                    # InputDataList
        if len(v1ing_input_data_list.get_list()) < 1:
            return ret
        # for V1beta1IngressList in InputDataList:
        for v1beta1_ingress_list in v1ing_input_data_list.get_list():
            # for V1beta1Ingress in V1beta1IngressList:
            for v1ing in v1beta1_ingress_list.items:
                # for V1beta1IngressRule in list[V1beta1IngressRule]:
                for v1beta1_ingress_rule in v1ing.spec.rules:
                    hostname = self._check_and_modify_hostname(
                        v1beta1_ingress_rule.host)
                    if hostname is None:
                        continue
                    location = K8sResponseHelper.LOCATION_NOT_DEFINE
                    ip = self._get_external_ip(v1ing)
                    # for K8sResponseExternal in K8sResponseExternalList:
                    for external in list_of_nginx_ingress_external:
                        ip = external.get_ip()
                        ex = K8sResponseExternal(v1ing, hostname, ip, location)
                        ret.append(ex)
        ret.extend(list_of_ignore_nginx_ingress_external)
        return ret

    def _has_external_ip(self, v1ing):
        if v1ing.status.load_balancer.ingress is not None:
            return True
        else:
            return False

    def _get_external_ip(self, v1ing):
        if self._has_external_ip(v1ing):
            return v1ing.status.load_balancer.ingress[0].ip
        else:
            return None

    def _get_nginx_ingress_external_list(self, li):
        ret = []
        for external in li:
            if self._is_nginx_ingress(external.get_hostname()):
                ret.append(external)
        return ret

    def _get_ignore_nginx_ingress_external_list(self, li):
        ret = []
        for external in li:
            if not self._is_nginx_ingress(external.get_hostname()):
                ret.append(external)
        return ret

    def _is_nginx_ingress(self, hostname):
        if K8sResponseHelper.NGINX_INGRESS_SUFFIX in hostname:
            return True
        else:
            return False

    def _check_and_modify_hostname(self, hostname):
        return hostname.split(self._get_fqdn(hostname))[0]

    def _get_fqdn(self, hostname):
        return ".%s" % (socket.getaddrinfo(socket.gethostname(), 0, flags=socket.AI_CANONNAME)[0][3])
