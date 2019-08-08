#!/usr/bin/env python3
# coding: utf-8

from rdbox.k8s_response_external_list import K8sResponseExternalList
from rdbox.k8s_client_list import K8sClientList
from rdbox.k8s_client_core_v1_api import K8sClientCoreV1Api
from rdbox.k8s_client_extensions_v1beta1_api import K8sClientExtensionsV1beta1Api
from rdbox.k8s_response_helper_v1nodelist import K8sResponseHelperV1NodeList
from rdbox.k8s_response_helper_v1beta1ingressList import K8sResponseHelperV1beta1IngressList
from rdbox.rdbox_node_report import RdboxNodeReport
from rdbox.rdbox_node_list import RdboxNodeList
from rdbox.ansible_rdbox_node_formatter import AnsibleRdboxNodeFormatter
from rdbox.etchosts_rdbox_node_formatter import EtchostsRdboxNodeFormatter


class GetCommand(object):
    def __init__(self, intermediate_data, final_data, report_data, collect_input_data_algorithm, convert_intermediate_data_algorithm, convert_report_data_algorithm):
        self.intermediate_data = intermediate_data
        self.final_data = final_data
        self.report_data = report_data
        self.collect_input_data_algorithm = collect_input_data_algorithm
        self.convert_intermediate_data_algorithm = convert_intermediate_data_algorithm
        self.convert_report_data_algorithm = convert_report_data_algorithm

    def execute(self):
        intermediate_data = self.intermediate_data(
            self.collect_input_data_algorithm, self.convert_intermediate_data_algorithm)
        intermediate_data = intermediate_data.call()
        final_data = self.final_data(intermediate_data)
        report_data = self.report_data(
            final_data, self.convert_report_data_algorithm)
        return report_data.output_report()


class GetCommandBuilder(object):
    def __init__(self):
        self.intermediate_data = None
        self.final_data = None
        self.report_data = None
        self.collect_input_data_algorithm = None
        self.convert_intermediate_data_algorithm = None
        self.convert_report_data_algorithm = None

    def set_intermediate_data(self, intermediate_data):
        self.intermediate_data = intermediate_data

    def set_final_data(self, final_data):
        self.final_data = final_data

    def set_report_data(self, report_data):
        self.report_data = report_data

    def set_collect_input_data_algorithm(self, collect_input_data_algorithm):
        self.collect_input_data_algorithm = collect_input_data_algorithm

    def set_convert_intermediate_data_algorithm(self, convert_intermediate_data_algorithm):
        self.convert_intermediate_data_algorithm = convert_intermediate_data_algorithm

    def set_convert_report_data_algorithm(self, convert_report_data_algorithm):
        self.convert_report_data_algorithm = convert_report_data_algorithm

    def setting(self):
        assert False

    def build(self, format_type):
        self.setting()
        from rdbox.classifier_for_get_command import ClassifierForGetCommand
        if format_type == ClassifierForGetCommand.FORMAT_LIST[1]:
            self.convert_report_data_algorithm = AnsibleRdboxNodeFormatter()
        elif format_type == ClassifierForGetCommand.FORMAT_LIST[2]:
            self.convert_report_data_algorithm = EtchostsRdboxNodeFormatter()
        return GetCommand(self.intermediate_data, self.final_data, self.report_data, self.collect_input_data_algorithm, self.convert_intermediate_data_algorithm, self.convert_report_data_algorithm)


class GetCommandNode(GetCommandBuilder):
    def setting(self):
        self.set_intermediate_data(K8sResponseExternalList)
        self.set_final_data(RdboxNodeList)
        self.set_report_data(RdboxNodeReport)
        ###
        k8s_client_list = K8sClientList()
        k8s_client_list.add(K8sClientCoreV1Api("list_node"))
        self.set_collect_input_data_algorithm(k8s_client_list)
        ###
        self.set_convert_intermediate_data_algorithm(
            K8sResponseHelperV1NodeList())
        self.set_convert_report_data_algorithm(AnsibleRdboxNodeFormatter())


class GetCommandK8sExternalSvc(GetCommandBuilder):
    def setting(self):
        self.set_intermediate_data(K8sResponseExternalList)
        self.set_final_data(RdboxNodeList)
        self.set_report_data(RdboxNodeReport)
        ###
        k8s_client_list = K8sClientList()
        k8s_client_list.add(K8sClientCoreV1Api(
            "list_service_for_all_namespaces"))
        k8s_client_list.add(K8sClientExtensionsV1beta1Api(
            "list_ingress_for_all_namespaces"))
        self.set_collect_input_data_algorithm(k8s_client_list)
        ###
        self.set_convert_intermediate_data_algorithm(
            K8sResponseHelperV1beta1IngressList())
        self.set_convert_report_data_algorithm(EtchostsRdboxNodeFormatter())
