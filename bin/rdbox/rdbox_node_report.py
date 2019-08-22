#!/usr/bin/env python3
# coding: utf-8


class RdboxNodeReport(object):
    def __init__(self, rdbox_node_list, formatter):
        self.rdbox_node_list = rdbox_node_list
        self.formatter = formatter

    def output_report(self):
        return self.formatter.output_report(self.rdbox_node_list)
