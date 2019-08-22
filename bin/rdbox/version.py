#!/usr/bin/env python3
# coding: utf-8

import subprocess

from logging import getLogger
r_logger = getLogger('rdbox_cli')
r_print = getLogger('rdbox_cli').getChild("stdout")


class Version(object):
    @classmethod
    def command_version(cls, args):
        cmd = 'apt-cache policy rdbox | grep "%s" | sed -E "%s"' % (
            r"\*\*\*", r"s@.*\*\*\*\s(\S+)(\s.*|$)@\\1@g")
        msg = subprocess.check_output(cmd, shell=True)
        msg = msg.rstrip()
        r_print.critical("RDBOX's Middleware Version: " + msg.decode('utf-8'))
        return True
