#!/usr/bin/env python3
# coding: utf-8

from rdbox.classifier_for_enable_disable_command import ClassifierForEnableDisableCommand
from rdbox.crontab_control import CrontabControl
from rdbox.helm_control import HelmControl
from rdbox.ansible_control import AnsibleControl

from logging import getLogger
r_logger = getLogger('rdbox_cli')
r_print = getLogger('rdbox_cli').getChild("stdout")


class ClassifierForEnableCommand(ClassifierForEnableDisableCommand):

    # crontab format
    # [SCHEDULE, COMMAND, COMMENTS]
    SETTINGS_FUNCTYPES = [
        ["* * * * *", "/usr/bin/sudo /usr/bin/python3 /opt/rdbox/bin/rdbox_cli hidden hosts_for_k8s_external_svc >/dev/null 2>&1",
            ClassifierForEnableDisableCommand.FUNCTYPES_LIST[0]]
    ]

    @classmethod
    def execute(cls, args):
        if cls._validation(args.function_type) is False:
            return False
        # helm
        helm_chart_name = cls._map_func_to_helm(args.function_type)
        helm = HelmControl()
        is_success = helm.install_all(helm_chart_name, args)
        if not is_success:
            return False
        if args.function_type == cls.FUNCTYPES_LIST[0]:
            # add cron
            c = CrontabControl()
            if not c.write_all(args.function_type, cls.SETTINGS_FUNCTYPES[0]):
                return False
        elif args.function_type == cls.FUNCTYPES_LIST[1]:
            ret = -1
            cache_url = helm.get_docker_registry_ingress_hosts_all(
                helm_chart_name, args)
            if cache_url != "":
                ac = AnsibleControl()
                ret = ac.playbook_dockerconfig_enable_all(cache_url)
            else:
                ac = AnsibleControl()
                ret = ac.playbook_dockerconfig_disable_all()
            if ret < 0:
                return False
            cls._print_complete_message(cache_url)
        #############
        print("Finish!!")
        return True

    @classmethod
    def _print_complete_message(cls, cache_url):
        r_print.info('###### INFO ######')
        r_print.info(
            'All processing is completed. It takes a few minutes to reflect the network settings.')
        r_print.info('')
        r_print.info(
            'Test Operation: If the response is "{"repositories": []}",')
        r_print.info('it is successful!!')
        r_print.info('$ curl {cache_url}'.format(cache_url=cache_url))
        r_print.info('{"repositories": []}')
        r_print.info('')
        r_print.info('##################')
