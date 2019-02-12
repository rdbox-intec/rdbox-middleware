#!/usr/bin/env python3
# coding: utf-8

import shutil
import fcntl
import subprocess
import rdbox.config
from rdbox.get_command import GetCommandK8sExternalSvc
from rdbox.classifier_for_get_command import ClassifierForGetCommand

from logging import getLogger, StreamHandler, Formatter
r_logger = getLogger('rdbox_cli')
r_print = getLogger('rdbox_cli').getChild("stdout")

class DnsK8sExternalSvc(object):

    HOSTS_FILENAME_FOR_DNSMASQ = rdbox.config.get("kubernetes", "hosts_for_k8s_external_svc")

    @classmethod
    def execute(cls, args):
        lockfilePath = '/var/lock/rdbox_dns_k8s_external_svc.py.lock'
        with open(lockfilePath , "w") as lockFile:
            try:
                fcntl.flock(lockFile, fcntl.LOCK_EX | fcntl.LOCK_NB)
                d = DnsK8sExternalSvc()
                return d._main()
            except:
                import traceback
                r_logger.error(traceback.format_exc())
                r_logger.error('process already exists')
                return False

    def _main(self):
        get_command_k8s_external_svc = GetCommandK8sExternalSvc()
        get_command = get_command_k8s_external_svc.build(ClassifierForGetCommand.FORMAT_LIST[2])
        _, now_report = get_command.execute()
        before_report = self._read_file(DnsK8sExternalSvc.HOSTS_FILENAME_FOR_DNSMASQ)
        if now_report != before_report:
            self._write_file(DnsK8sExternalSvc.HOSTS_FILENAME_FOR_DNSMASQ, now_report)
            r_logger.info("%s" % ("File Change!!"))
            cmd = '{systemctl} reload dnsmasq.service'.format(systemctl=shutil.which('systemctl'))
            is_success = self._subprocess_popen_with_judge(cmd, 'Failed')
            if is_success:
                r_logger.info("%s" % ("daemon reloaded!!"))
                return True
            else:
                r_logger.error("%s" % ("daemon failed!!"))
                return False
        else:
            r_logger.info("%s" % ("No change!!"))
            return True

    def _read_file(self, file_name):
        f = None
        try:
            f = open(file_name, "r")
            lines = f.read()
        except FileNotFoundError:
            lines = ""
        finally:
            if f:
                f.close()
            return lines

    def _write_file(self, file_name, content):
        f = open(file_name, "w")
        f.write(content)
        f.close()

    def _subprocess_popen_with_judge(self, command, *args):
        is_success = False
        p = subprocess.Popen(command.split(" "), stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        for line in iter(p.stdout.readline,b''):
            str_line = line.rstrip().decode("utf8")
            r_logger.debug(str_line)
            for ok_word in args:
                if ok_word not in str_line:
                    is_success = True
        return is_success



if __name__=="__main__":
    DnsK8sExternalSvc.main()
