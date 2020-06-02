#!/usr/bin/env python3
# coding: utf-8

from rdbox.rdbox_node_formatter import RdboxNodeFormatter
import rdbox.config

from logging import getLogger
r_logger = getLogger('rdbox_cli')
r_print = getLogger('rdbox_cli').getChild("stdout")


class BlockstoreRdboxNodeFormatter(RdboxNodeFormatter):
    def output_report(self, rdbox_node_list):
        output_str = ""
        grouping_dict = rdbox_node_list.group_by("location")
        matchCount = 0
        for key, list_of_group in grouping_dict.items():
            if key == 'edge':
                continue
            else:
                matchCount = matchCount + len(list_of_group)
        maxReplicas = int(rdbox.config.get('apps', 'openebs_max_replicas'))
        if matchCount >= maxReplicas:
            matchCount = maxReplicas
        output_str = str(matchCount - 1)
        return rdbox_node_list, output_str
