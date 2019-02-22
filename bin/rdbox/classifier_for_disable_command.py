#!/usr/bin/env python3
# coding: utf-8

from rdbox.ansible_control import AnsibleControl
from rdbox.classifier_for_enable_disable_command import \
    ClassifierForEnableDisableCommand
from rdbox.crontab_control import CrontabControl
from rdbox.helm_control import HelmControl

from logging import getLogger, StreamHandler, Formatter
r_logger = getLogger('rdbox_cli')
r_print = getLogger('rdbox_cli').getChild("stdout")


class ClassifierForDisableCommand(ClassifierForEnableDisableCommand):


    @classmethod
    def execute(cls, args):
        if cls._validation(args.function_type) is False:
            return False
        # helm
        helm_chart_name = cls._map_func_to_helm(args.function_type)
        helm = HelmControl()
        is_success = helm.delete_all(helm_chart_name, args)
        if not is_success:
            return False
        if args.function_type == cls.FUNCTYPES_LIST[0]:
            # add cron
            c = CrontabControl()
            if not c.remove_all(args.function_type):
                return False
        elif args.function_type == cls.FUNCTYPES_LIST[1]:
            # exec ansible
            ac = AnsibleControl()
            return ac.playbook_dockerconfig_disable_all()
        else:
            return True
        #############
        r_print.info("Finish!!")
        return True
