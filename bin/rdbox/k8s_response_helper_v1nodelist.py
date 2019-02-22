#!/usr/bin/env python3
# coding: utf-8

from rdbox.k8s_response_helper import K8sResponseHelper
from rdbox.k8s_response_external import K8sResponseExternal
from kubernetes.client.models import V1NodeList

class K8sResponseHelperV1NodeList(K8sResponseHelper):

    def parse(self):
        """
        Parse InputDataList[kubernetes/client/models/*] to list[K8sResponseExternal].
            InputDataList[kubernetes/client/models/*] set by K8sResponseHelper.set_input_data_list()
            Execute From K8sResponseExternalList.call()
        :return: list[K8sResponseExternal]
        """
        ret = []
        v1node_input_data_list = self.get_input_data_list().get_by_instance(V1NodeList) # InputDataList = list[K8SRESP]
        if len(v1node_input_data_list.get_list()) < 1:
            return ret
        for v1_node_list in v1node_input_data_list.get_list():         # v1_node_list = V1NodeList
            for v1node in v1_node_list.items:                          # v1node = V1Node
                if not self._is_ready(v1node):
                    continue
                hostname = v1node.metadata.labels.get("kubernetes.io/hostname")
                if hostname is None:
                    continue
                ip = v1node.metadata.annotations.get("flannel.alpha.coreos.com/public-ip")
                if ip is None:
                    continue
                location = v1node.metadata.labels.get("node.rdbox.com/location", K8sResponseHelper.LOCATION_NOT_DEFINE)
                ex = K8sResponseExternal(v1node, hostname, ip, location)
                ret.append(ex)
        return ret

    def _is_ready(self, v1node):
        for conditions in v1node.status.conditions:
            if conditions.type == "Ready":
                if conditions.status == "True":
                    return True
            else:
                continue
        return False
