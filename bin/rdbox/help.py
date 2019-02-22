#!/usr/bin/env python3
# coding: utf-8

from logging import getLogger, StreamHandler, Formatter
r_logger = getLogger('rdbox_cli')
r_print = getLogger('rdbox_cli').getChild("stdout")

class Help(object):
    @classmethod
    def command_help(cls, args, parser):
        r_print.info(parser.parse_args([args.command, '--help']))
