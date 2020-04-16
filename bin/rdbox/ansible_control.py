#!/usr/bin/env python3
# coding: utf-8

import os
import sys
import errno
from collections import namedtuple
from ansible.executor.playbook_executor import PlaybookExecutor
from ansible.inventory.manager import InventoryManager
from ansible.parsing.dataloader import DataLoader
from ansible.vars.manager import VariableManager

import rdbox.config
from rdbox.classifier_for_get_command import ClassifierForGetCommand
from rdbox.get_command import GetCommandNode
from rdbox.std_logger_writer import StdLoggerWriter

from logging import getLogger
r_logger = getLogger('rdbox_cli')
r_print = getLogger('rdbox_cli').getChild("stdout")


class AnsibleControl(object):

    def __init__(self):
        pass

    def playbook_cacertificates_all(self):
        playbook_name = 'docker-service'
        tags = set()
        tags.add("ca-certificates")
        extra_vars = {}
        return self._common_playbook(playbook_name, tags, extra_vars)

    def playbook_dockerconfig_enable_all(self, registry_mirrors_url):
        playbook_name = 'docker-service'
        tags = set()
        tags.add("docker_config")
        tags.add("docker_service")
        extra_vars = {"registrymirrors": {
            "registry-mirrors": [registry_mirrors_url]}}
        return self._common_playbook(playbook_name, tags, extra_vars)

    def playbook_dockerconfig_disable_all(self):
        playbook_name = 'docker-service'
        tags = set()
        tags.add("docker_config")
        tags.add("docker_service")
        extra_vars = {"registrymirrors": {}}
        return self._common_playbook(playbook_name, tags, extra_vars)

    def _common_playbook(self, playbook_name, tags_set, extra_vars_dict):
        if 'SUDO_USER' in os.environ:
            user = os.environ['SUDO_USER']
        else:
            user = os.environ['USER']
        keyfile_path = "/home/{user}/.ssh/id_rsa".format(user=user)
        ret = self.playbook_all(playbook_name, list(
            tags_set), extra_vars_dict, keyfile_path)
        if ret == 0:
            return True
        else:
            return False

    def playbook_all(self, playbook_name, tags_set, extra_vars_dict,
                     keyfile_path):
        ret = -1
        playbook_path = self._preinstall_playbook_path_builder(playbook_name)
        r_print.debug(playbook_path)
        inventry_path = '{work_dir}/.inventry'.format(
            work_dir=rdbox.config.get("ansible", "work_dir"))
        try:
            loader = DataLoader()
            self._create_inventry_file_from_k8s(inventry_path)
            inventory = InventoryManager(loader=loader, sources=inventry_path)
            variable_manager = VariableManager(
                loader=loader, inventory=inventory)
            variable_manager.extra_vars = extra_vars_dict
            if not os.path.exists(playbook_path):
                raise IOError(
                    errno.ENOENT, os.strerror(errno.ENOENT), playbook_path)
            Options = namedtuple('Options', ['listtags',
                                             'listtasks',
                                             'listhosts',
                                             'syntax',
                                             'connection',
                                             'module_path',
                                             'forks',
                                             'remote_user',
                                             'private_key_file',
                                             'ssh_common_args',
                                             'ssh_extra_args',
                                             'sftp_extra_args',
                                             'scp_extra_args',
                                             'become',
                                             'become_method',
                                             'become_user',
                                             'verbosity',
                                             'check',
                                             'diff',
                                             'tags'])
            options = Options(listtags=False,
                              listtasks=False,
                              listhosts=False,
                              syntax=False,
                              connection='smart',
                              module_path=None,
                              forks=5,
                              remote_user=None,
                              private_key_file=keyfile_path,
                              ssh_common_args=None,
                              ssh_extra_args=None,
                              sftp_extra_args=None,
                              scp_extra_args=None,
                              become=True,
                              become_method='sudo',
                              become_user='root',
                              verbosity=None,
                              check=False,
                              diff=False,
                              tags=tags_set)
            passwords = {}
            pbex = PlaybookExecutor(playbooks=[playbook_path],
                                    inventory=inventory,
                                    variable_manager=variable_manager,
                                    loader=loader,
                                    options=options,
                                    passwords=passwords)
            # redirect
            bak_stdout = sys.stdout
            bak_stderr = sys.stderr
            sys.stdout = StdLoggerWriter(r_print.debug)
            sys.stderr = StdLoggerWriter(r_print.info)
            ret = pbex.run()
        except FileNotFoundError:
            sys.stdout = bak_stdout
            sys.stderr = bak_stderr
            import traceback
            r_print.error(traceback.format_exc())
            ret = -1
        except Exception:
            sys.stdout = bak_stdout
            sys.stderr = bak_stderr
            import traceback
            r_print.error(traceback.format_exc())
            ret = -1
        finally:
            sys.stdout = bak_stdout
            sys.stderr = bak_stderr
        # Cleanup
        try:
            self._remove_file(inventry_path)
        except Exception:
            # No problem
            pass
        return ret

    def _create_inventry_file_from_k8s(self, inventry_path):
        get_command_node = GetCommandNode()
        get_command = get_command_node.build(
            ClassifierForGetCommand.FORMAT_LIST[1])
        _, now_report = get_command.execute()
        self._write_file(inventry_path, now_report)

    @staticmethod
    def _write_file(file_name, content):
        f = open(file_name, "w")
        f.write(content)
        f.close()

    @staticmethod
    def _preinstall_playbook_path_builder(playbook_name):
        playbook_path = rdbox.config.get("ansible", "playbook_dir")
        playbook_filename = 'site.yml'
        return os.path.join(playbook_path, playbook_name, playbook_filename)

    @staticmethod
    def _remove_file(self, path):
        os.remove(path)
