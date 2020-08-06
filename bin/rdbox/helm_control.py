#!/usr/bin/env python3
# coding: utf-8

import yaml
import os
import re
import rdbox.config
import subprocess
from distutils.dir_util import copy_tree

from logging import getLogger
r_logger = getLogger('rdbox_cli')
r_print = getLogger('rdbox_cli').getChild("stdout")


class HelmControl(object):

    HELM_BIN_PATH = rdbox.config.get("helm", "bin_path")
    HELM_GLOBAL_FLG = ["debug", "home", "host", "kube-context",
                       "kubeconfig", "tiller-connection-timeout", "tiller-namespace"]
    HELM_INSTALL_FLG = ["ca-file", "cert-file", "dep-up", "description", "devel", "dry-run", "key-file", "keyring", "name", "name-template", "namespace", "no-crd-hook", "no-hooks", "password",
                        "replace", "repo", "set", "set-file", "set-string", "timeout", "tls", "tls-ca-cert", "tls-cert", "tls-hostname", "tls-key", "tls-verify", "username", "values", "verify", "wait"]
    HELM_DELETE_FLG = ["description", "dry-run", "no-hooks", "purge", "timeout",
                       "tls", "tls-ca-cert", "tls-cert", "tls-hostname", "tls-key", "tls-verify"]

    def __init__(self):
        pass

    def install_all(self, helm_chart_name, args):
        chart_path = os.path.join(rdbox.config.get(
            "helm", "chart_dir"), helm_chart_name)
        work_path = os.path.join(rdbox.config.get(
            "helm", "work_dir"), helm_chart_name)
        original_user = os.environ['SUDO_USER'] if 'SUDO_USER' in os.environ else os.environ['USER']
        helm_home = self._get_helm_home(original_user)
        kube_config = self._get_kube_config(original_user)
        # helm get chart
        self.get_chart(chart_path, work_path)
        # helm dep up
        is_success = self.dependency("update", work_path, helm_home)
        if is_success:
            r_print.info("Enable helm-charts.")
        else:
            r_print.info("Disable helm-charts.")
            return False
        # helm install
        is_success = self.install(
            work_path, helm_chart_name, helm_home, kube_config, args.set)
        if is_success:
            r_print.info("Enable helm-charts.")
        else:
            r_print.info("Disable helm-charts.")
            return False
        return True

    def delete_all(self, helm_chart_name, args):
        original_user = os.environ['SUDO_USER'] if 'SUDO_USER' in os.environ else os.environ['USER']
        helm_home = self._get_helm_home(original_user)
        kube_config = self._get_kube_config(original_user)
        is_success = self.delete(helm_chart_name, helm_home, kube_config)
        if is_success:
            r_print.info("Disable helm-charts.")
        else:
            r_print.error("Failed remove helm-charts.(Enable helm-carts)")
            return False
        return True

    def get_docker_registry_ingress_hosts_all(self, helm_chart_name, args):
        # Add an ingress host to the Docker cache configuration.
        # (example of default "cache-registry.rdbox.lan")
        chart_path = os.path.join(rdbox.config.get(
            "helm", "chart_dir"), helm_chart_name)
        cache_url = ""
        # ex) for --set docker-registry.ingress.hosts=cache-registry.rdbox.lan
        _, set_dict = self.parse_set_flag(args.set)
        if "docker-registry.ingress.hosts" in set_dict:
            cache_url = set_dict.get("docker-registry.ingress.hosts", "")
        else:
            try:
                values_path = os.path.join(chart_path, "values.yaml")
                f = open(values_path, "r")
                data = yaml.safe_load(f)
                cache_url = "https://" + \
                    data.get("docker-registry").get("ingress").get("hosts")[0]
            except Exception:
                import traceback
                r_logger.error(traceback.format_exc())
                cache_url = ""
            finally:
                f.close()
        return cache_url

    def get_chart(self, src, dst):
        copy_tree(src, dst)

    def delete(self, helm_chart_name, helm_home, kube_config, **kwargs):
        base_cmd = '{helm} uninstall --kubeconfig {kube_config} --namespace {namespace} {name}'.format(
            helm=self.HELM_BIN_PATH, helm_home=helm_home, kube_config=kube_config, namespace=rdbox.config.get("kubernetes", "rdbox_namespace"), name=helm_chart_name)
        base_cmd += self._kwargs_to_command(self.HELM_DELETE_FLG, **kwargs)
        is_success = self._subprocess_popen_with_judge(
            base_cmd.strip(), "uninstalled", "not found")
        return is_success

    def install(self, work_path, helm_chart_name, helm_home, kube_config, sets, **kwargs):
        parsed_set_command, _ = self.parse_set_flag(
            sets)  # ex) "--set a=1,b=2"
        base_cmd = '{helm} install {name} {work_path} --kubeconfig {kube_config} --namespace {namespace} {sets}'.format(
            helm=self.HELM_BIN_PATH, work_path=work_path, name=helm_chart_name, helm_home=helm_home, kube_config=kube_config, namespace=rdbox.config.get("kubernetes", "rdbox_namespace"), sets=parsed_set_command)
        base_cmd += self._kwargs_to_command(self.HELM_INSTALL_FLG, **kwargs)
        is_success = self._subprocess_popen_with_judge(
            base_cmd.strip(), "STATUS: deployed", "already exists")
        return is_success

    def dependency(self, command, work_path, helm_home, **kwargs):
        base_cmd = '{helm} dependency {command} {work_path}'.format(
            helm=self.HELM_BIN_PATH, command=command, helm_home=helm_home, work_path=work_path)
        base_cmd += self._kwargs_to_command(**kwargs)
        is_success = self._subprocess_popen_with_judge(
            base_cmd.strip(), "Deleting outdated charts", "No requirements found")
        return is_success

    def parse_set_flag(self, set_string):
        sets = ""
        set_dict = {}
        if set_string != "not_set":
            set_list = set_string.split(",")
            for item in set_list:
                k_v = item.split("=")
                if len(k_v) == 2:
                    set_dict[k_v[0]] = k_v[1]
            validated_sets = ""
            validated_sets_len = len(set_dict)
            for i, (key, value) in enumerate(set_dict.items()):
                key = re.sub(r'\;|\&|\(|\)|\$|\<|\>|\*|\?|\{|\}|\[|\]|\!|\"|\'', '', str(key))
                value = re.sub(r'\;|\&|\(|\)|\$|\<|\>|\*|\?|\{|\}|\[|\]|\!|\"|\'', '', str(value))
                validated_sets = validated_sets + \
                    "{key}={value}".format(key=key, value=value)
                if i < validated_sets_len - 1:
                    validated_sets += ","
            sets = "--set %s" % validated_sets
        return sets, set_dict

    def _subprocess_popen_with_judge(self, command, *args):
        is_success = False
        p = subprocess.Popen(command.split(
            " "), stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        for line in iter(p.stdout.readline, b''):
            str_line = line.rstrip().decode("utf8")
            r_print.info(str_line)
            for ok_word in args:
                if ok_word in str_line:
                    is_success = True
        return is_success

    def _get_helm_home(self, user):
        path = ""
        if user == "root":
            path = "/root/.helm"
        else:
            path = "/home/{user}/.helm".format(user=user)
        return path

    def _get_kube_config(self, user):
        path = ""
        if user == "root":
            path = "/root/.kube/config"
        else:
            path = "/home/{user}/.kube/config".format(user=user)
        return path

    def _kwargs_to_command(self, external_flag_list=None, **kwargs):
        exlist = []
        if external_flag_list is None:
            exlist = []
        else:
            exlist = external_flag_list
        command = ""
        for key, value in kwargs:
            if key in exlist:
                command += "--{key} {value}".format(key=key, value=value)
                command += " "
                continue
            if key in self.HELM_GLOBAL_FLG:
                command += "--{key} {value}".format(key=key, value=value)
                command += " "
                continue
        return command
