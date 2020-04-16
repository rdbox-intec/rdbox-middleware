#!/usr/bin/env python3
# coding: utf-8

import os
from crontab import CronTab

from logging import getLogger
r_logger = getLogger('rdbox_cli')
r_print = getLogger('rdbox_cli').getChild("stdout")


class CrontabControl(object):
    def __init__(self):
        self.cron = CronTab(
            user=os.environ['SUDO_USER'] if 'SUDO_USER' in os.environ else os.environ['USER'])
        self.job = None

    def write_all(self, job_name, list_format_job):
        ret = False
        is_active = self.has_specific_job(job_name)
        if is_active:
            r_print.info("Enable cron.")
            ret = True
        else:
            if self.write_job(*list_format_job):
                r_print.info("Enable cron.")
                ret = True
            else:
                r_print.info("Disable cron.")
                ret = False
        return ret

    def remove_all(self, job_name):
        ret = False
        is_active = self.has_specific_job(job_name)
        if is_active:
            if self.remove_specific_job(job_name):
                r_print.info("Disable cron.")
                ret = True
            else:
                r_print.info("Failed remove cron.(Enable cron.)")
                return False
        else:
            r_print.info("Disable cron.")
            ret = True
        return ret

    def write_job(self, schedule, command, comment=""):
        try:
            self.job = self.cron.new(command=command, comment=comment)
            self.job.setall(schedule)
            self.cron.write()
            return True
        except Exception:
            return False

    def has_specific_job(self, comment):
        if self.job is None:
            try:
                self.read_jobs()
            except IOError:
                return False
        comment_list = self.cron.find_comment(comment)
        tmp = []
        for item in comment_list:
            tmp.append(item)
        return len(tmp) >= 1

    def remove_specific_job(self, comment):
        try:
            self.cron.remove_all(comment=comment)
            self.cron.write()
            return True
        except Exception:
            return False

    def read_jobs(self):
        self.cron = CronTab(
            user=os.environ['SUDO_USER'] if 'SUDO_USER' in os.environ else os.environ['USER'])
