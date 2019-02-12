#!/usr/bin/env python3
# coding: utf-8

from rdbox.get_command import GetCommandNode, GetCommandK8sExternalSvc

from logging import getLogger, StreamHandler, Formatter
r_logger = getLogger('rdbox_cli')
r_print = getLogger('rdbox_cli').getChild("stdout")

class ClassifierForGetCommand(object):

    GETTYPES = "node|k8s_external_svc"
    GETTYPES_LIST = GETTYPES.split("|")
    FORMAT = "default|ansible|hosts"
    FORMAT_LIST = FORMAT.split("|")

    DEFAULT_FORMAT = {
                         GETTYPES_LIST[0]: FORMAT_LIST[1],
                         GETTYPES_LIST[1]: FORMAT_LIST[2]
                     }

    @classmethod
    def execute(cls, args):
        if cls._validation(args.info_type, args.format) is False:
            return False
        #############
        if args.format == "default":
            args.format = cls.DEFAULT_FORMAT[args.info_type]
        #############
        return cls._build_and_execute_get_command(args.info_type, args.format)
        #############

    @classmethod
    def _build_and_execute_get_command(cls, info_type, format_type):
        if info_type == cls.GETTYPES_LIST[0]:
            info_type_class = GetCommandNode()
        elif info_type == cls.GETTYPES_LIST[1]:
            info_type_class = GetCommandK8sExternalSvc()
        else:
            return False
        command_for_get = info_type_class.build(format_type)
        command_for_get.execute()
        return True

    @classmethod
    def _validation(cls, info_type, format_type):
        if info_type not in cls.GETTYPES_LIST:
            r_print.error("type_list is invalid.")
            return False
        if format_type not in cls.FORMAT_LIST:
            r_print.error("format is invalid.")
            return False
        return True
