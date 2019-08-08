#!/usr/bin/env python3
# coding: utf-8

import unittest

from rdbox.classifier_for_get_command import ClassifierForGetCommand


class TestClassifierForGetCommand(unittest.TestCase):

    def test_validation_type_node(self):
        info_type = "node"
        format_type = "default"
        expected = True
        actual = ClassifierForGetCommand._validation(info_type, format_type)
        self.assertEqual(expected, actual)
        info_type = "node"
        format_type = "ansible"
        actual = ClassifierForGetCommand._validation(info_type, format_type)
        self.assertEqual(expected, actual)
        info_type = "node"
        format_type = "hosts"
        actual = ClassifierForGetCommand._validation(info_type, format_type)
        self.assertEqual(expected, actual)
        expected = False
        info_type = "node"
        format_type = "hogehoeg"
        actual = ClassifierForGetCommand._validation(info_type, format_type)
        self.assertEqual(expected, actual)

    def test_validation_type_k8s_external_svc(self):
        info_type = "k8s_external_svc"
        format_type = "default"
        expected = True
        actual = ClassifierForGetCommand._validation(info_type, format_type)
        self.assertEqual(expected, actual)
        info_type = "k8s_external_svc"
        format_type = "ansible"
        actual = ClassifierForGetCommand._validation(info_type, format_type)
        self.assertEqual(expected, actual)
        info_type = "k8s_external_svc"
        format_type = "hosts"
        actual = ClassifierForGetCommand._validation(info_type, format_type)
        self.assertEqual(expected, actual)
        expected = False
        info_type = "k8s_external_svc"
        format_type = "hogehoeg"
        actual = ClassifierForGetCommand._validation(info_type, format_type)
        self.assertEqual(expected, actual)

    def test_validation_type_hogehoge(self):
        info_type = "hogehoge"
        format_type = "default"
        expected = False
        actual = ClassifierForGetCommand._validation(info_type, format_type)
        self.assertEqual(expected, actual)


if __name__ == "__main__":
    unittest.main()
