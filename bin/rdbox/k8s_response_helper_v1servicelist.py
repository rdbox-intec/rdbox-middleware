#!/usr/bin/env python3
# coding: utf-8

from rdbox.k8s_response_helper import K8sResponseHelper
from rdbox.k8s_response_external import K8sResponseExternal
from kubernetes.client.models import V1ServiceList

class K8sResponseHelperV1ServiceList(K8sResponseHelper):

    def parse(self):
        """
        Parse InputDataList[kubernetes/client/models/*] to list[K8sResponseExternal].
            InputDataList[kubernetes/client/models/*] set by K8sResponseHelper.set_input_data_list()
            Execute From K8sResponseExternalList.call()
        :return: list[K8sResponseExternal]
        """
        ret = []
        v1svc_input_data_list = self.get_input_data_list().get_by_instance(V1ServiceList) # InputDataList = list[K8SRESP]
        if len(v1svc_input_data_list.get_list()) < 1:
            return ret
        for v1_service_list in v1svc_input_data_list.get_list():         # v1_service_list = V1ServiceList
            for v1srv in v1_service_list.items:                          # v1srv = V1Service
                if not self._has_external_ip(v1srv):
                    continue
                hostname = v1srv.metadata.name
                if hostname is None:
                    continue
                ip = self._get_external_ip(v1srv)
                if ip is None:
                    continue
                location = K8sResponseHelper.LOCATION_NOT_DEFINE
                ex = K8sResponseExternal(v1srv, hostname, ip, location)
                ret.append(ex)
        return ret

    def _has_external_ip(self, v1srv):
        if v1srv.status.load_balancer.ingress is not None:
            return True
        else:
            return False

    def _get_external_ip(self, v1srv):
        return v1srv.status.load_balancer.ingress[0].ip

