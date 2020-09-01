#!/usr/bin/env python3
# coding: utf-8

import base64
import shutil
import subprocess
import socket
import os
import json
import urllib.request
import kubernetes.client
from kubernetes.client.rest import ApiException
import rdbox.config
from rdbox.ansible_control import AnsibleControl
from rdbox.k8s_client_core_v1_api import K8sClientCoreV1Api

from logging import getLogger
r_logger = getLogger('rdbox_cli')
r_print = getLogger('rdbox_cli').getChild("stdout")


class ClassifierForInitCommand(object):

    PLATFORM_TYPES = "onprem"
    PLATFORM_TYPES_LIST = PLATFORM_TYPES.split("|")

    OPENSSL_PATH = shutil.which('openssl')
    OPENSSL_KEY_CERT_DIRPATH = rdbox.config.get("rdbox", "openssl_keycert_dir")
    OPENSSL_KEY_NAME = '{common_names}.key'.format(
        common_names=rdbox.config.get("kubernetes", "rdbox_common_certname"))
    OPENSSL_CRT_NAME = '{common_names}.crt'.format(
        common_names=rdbox.config.get("kubernetes", "rdbox_common_certname"))

    KUBECTL_COMMON_CERT_NAME = rdbox.config.get(
        "kubernetes", "rdbox_common_certname")
    KUBECTL_COMMON_CERT_NSPACE = rdbox.config.get(
        "kubernetes", "rdbox_namespace")

    @classmethod
    def execute(cls, args):
        if cls._validation(args) is False:
            return False
        # Step.1 & Step.2
        if cls._issue_secret() is False:
            return False
        # Step.3
        if cls._distribution_secret() is False:
            return False
        cls._print_separator("#")
        # End
        crt_path = os.path.join(
                cls.OPENSSL_KEY_CERT_DIRPATH, cls.OPENSSL_CRT_NAME)
        with open(crt_path) as file:
            text = file.read()
            r_print.info("")
            r_print.info("A server certificate for RDBOX external services.")
            r_print.info("Add it to your operating system and browser trust list.")
            r_print.info("")
            r_print.info('$ echo ' + '"' + text + '" > ' + 'Rdbox-Common-Tls.crt')
            r_print.info("")
        r_print.info("Finish!!")
        return True

    @classmethod
    def _issue_secret(cls):
        try:
            key_path = os.path.join(
                cls.OPENSSL_KEY_CERT_DIRPATH, cls.OPENSSL_KEY_NAME)
            crt_path = os.path.join(
                cls.OPENSSL_KEY_CERT_DIRPATH, cls.OPENSSL_CRT_NAME)
            if os.path.exists(key_path) and os.path.exists(crt_path):
                if cls._yes_no_input():
                    r_print.info("<<Step1. skip.>>")
                    cls._print_separator("#")
                    cls._kubectl_create_ns(cls.KUBECTL_COMMON_CERT_NSPACE)
                    cls._kubectl_secret_tls(key_path, crt_path)
                else:
                    cls._gen_key(key_path, crt_path)
                    cls._print_separator("#")
                    cls._kubectl_secret_tls(key_path, crt_path)
            else:
                cls._gen_key(key_path, crt_path)
                cls._print_separator("#")
                cls._kubectl_create_ns(cls.KUBECTL_COMMON_CERT_NSPACE)
                cls._kubectl_secret_tls(key_path, crt_path)
            cls._print_separator("#")
        except Exception:
            import traceback
            r_logger.error(traceback.format_exc())
            return False
        return True

    @classmethod
    def _distribution_secret(cls):
        r_print.info("<<Step3. Distribute self-certificate to all nodes.>>")
        ac = AnsibleControl()
        return ac.playbook_cacertificates_all()

    @classmethod
    def _validation(cls, args):
        master_hostname = rdbox.config.get("rdbox", "master_hostname")
        if socket.gethostname() != master_hostname:
            r_print.info(
                "This command can be executed only on the %s" % master_hostname)
            return False
        if os.getuid() != 0:
            r_print.info("non-root user!")
            return False
        return True

    @classmethod
    def _yes_no_input(cls):
        while True:
            choice = input("crt file already exists. \n" \
                           "Do you want to skip creating a new one? \n" \
                           "'yes' or 'no' [y/N]: ").lower()
            if choice in ['y', 'ye', 'yes', '']:
                return True
            elif choice in ['n', 'no']:
                return False

    @classmethod
    def _gen_key(cls, key_path, crt_path):
        r_print.info(
            "<<Step1. It is being issued a self-signed certificate.>>")
        os.makedirs(cls.OPENSSL_KEY_CERT_DIRPATH, exist_ok=True)
        req = urllib.request.Request("http://ipinfo.io")
        c = "JP"
        st = "Tokyo"
        locatin = "Tokyo"
        cn = "*.%s" % (socket.getaddrinfo(socket.gethostname(),
                                          0, flags=socket.AI_CANONNAME)[0][3])
        try:
            with urllib.request.urlopen(req) as res:
                body = res.read()
                content = json.loads(body.decode('utf8'))
                c = content.get("country")
                st = content.get("region")
                locatin = content.get("city")
            cmd = '{openssl} req -newkey rsa:4096 -nodes -sha256 -keyout {key_path} -x509 -days 365 -out {crt_path} -subj "/C={c}/ST={st}/L={loc}/CN={cn}" -addext "subjectAltName=DNS:{san}"'.format(
                openssl=cls.OPENSSL_PATH, key_path=key_path, crt_path=crt_path, c=c, st=st, loc=locatin, cn=cn, san=cn)
            r_print.info(cmd)
            subprocess.check_output(cmd, shell=True)
        except Exception as e:
            raise e

    @classmethod
    def _base64encode_from_file(cls, path):
        try:
            f = open(path, "r")
            s = f.read()
            b64 = base64.b64encode(s.encode('utf-8'))
        except Exception as e:
            import traceback
            r_logger.error(traceback.format_exc())
            raise e
        finally:
            f.close()
        return b64.decode('utf-8')

    @classmethod
    def _kubectl_create_ns(cls, ns):
        r_print.info("<<Step2. Set a certificate to k8s via secret.>>")
        meta_obj = kubernetes.client.V1ObjectMeta(name=ns)
        body = kubernetes.client.V1Namespace(metadata=meta_obj)
        body.metadata.name = ns
        opts = {"body": body}
        k8s_core_v1 = K8sClientCoreV1Api("create_namespace", opts)
        try:
            k8s_core_v1.call()
        except Exception:
            pass
        r_print.info("created ns")

    @classmethod
    def _kubectl_secret_tls(cls, key_path, crt_path):
        # delete
        opts = {"name": cls.KUBECTL_COMMON_CERT_NAME,
                "namespace": cls.KUBECTL_COMMON_CERT_NSPACE,
                "body": kubernetes.client.V1DeleteOptions()}
        k8s_core_v1 = K8sClientCoreV1Api("delete_namespaced_secret", opts)
        try:
            k8s_core_v1.call()
        except ApiException as e:
            if e.status == 404:
                pass
            else:
                raise e
        r_print.info("deleted secret tls")
        # create
        b64_key = cls._base64encode_from_file(key_path)
        b64_crt = cls._base64encode_from_file(crt_path)
        data = {"tls.crt": b64_crt, "tls.key": b64_key}
        metadata = {"name": cls.KUBECTL_COMMON_CERT_NAME,
                    "namespace": cls.KUBECTL_COMMON_CERT_NSPACE}
        body = kubernetes.client.V1Secret(
            data=data, metadata=metadata, type="kubernetes.io/tls")
        opts = {"namespace": cls.KUBECTL_COMMON_CERT_NSPACE, "body": body}
        k8s_core_v1 = K8sClientCoreV1Api("create_namespaced_secret", opts)
        try:
            k8s_core_v1.call()
        except Exception as e:
            raise e
        r_print.info("created secret tls")

    @classmethod
    def _print_separator(cls, sep, count=20):
        r_print.info("%s" % (sep * count))
