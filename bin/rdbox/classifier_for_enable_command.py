#!/usr/bin/env python3
# coding: utf-8

from rdbox.classifier_for_enable_disable_command import ClassifierForEnableDisableCommand
from rdbox.crontab_control import CrontabControl
from rdbox.helm_control import HelmControl
from rdbox.ansible_control import AnsibleControl
from rdbox.get_command import GetCommandBlockstoreCount

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
        helm_chart_name_list = cls._map_func_to_helm(args.function_type)
        helm = HelmControl()
        if args.function_type == cls.FUNCTYPES_LIST[0]:
            for index, helm_chart_name in enumerate(helm_chart_name_list):
                r_print.info('')
                r_print.info('###### helm job {idx}/{total} {chartname} ######'.format(idx=str(index + 1), total=str(len(helm_chart_name_list)), chartname=helm_chart_name))
                if helm_chart_name == cls.HELMTYPES_LIST[1]:
                    cls._set_replica_count_to_args(args)
                    is_success = helm.install_all(helm_chart_name, args)
                else:
                    is_success = helm.install_all(helm_chart_name, args)
                if not is_success:
                    return False
            r_print.info('###### characteristic job for {func} ######'.format(func=args.function_type))
            # add cron
            c = CrontabControl()
            if not c.write_all(args.function_type, cls.SETTINGS_FUNCTYPES[0]):
                return False
        elif args.function_type == cls.FUNCTYPES_LIST[1]:
            for index, helm_chart_name in enumerate(helm_chart_name_list):
                r_print.info('')
                r_print.info('###### helm job {idx}/{total} ######'.format(idx=str(index + 1), total=str(len(helm_chart_name_list))))
                is_success = helm.install_all(helm_chart_name, args)
                if not is_success:
                    return False
            r_print.info('###### characteristic job for {func} ######'.format(func=args.function_type))
            ret = -1
            cache_url = helm.get_docker_registry_ingress_hosts_all(
                helm_chart_name_list[0], args)
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
        r_print.info('$ curl {cache_url}/v2/_catalog'.format(cache_url=cache_url))
        r_print.info('{"repositories": []}')
        r_print.info('')
        r_print.info('##################')
    
    @classmethod
    def _get_blockstore_replica_count(cls):
        replicas = 1
        try:
            info_type_class = GetCommandBlockstoreCount()
            command_for_get = info_type_class.build()
            _, replicas = command_for_get.execute()
        except Exception:
            r_logger.debug('Failed to retrieve data. Use the minimum value.')
        return replicas
    
    @classmethod
    def _set_replica_count_to_args(cls, args):
        replicas = cls._get_blockstore_replica_count()
        set_string_for_replicas = 'storageClass.ReplicaCount={replicas}'.format(replicas=str(replicas))
        args.set = args.set + ',' + set_string_for_replicas
        return args
