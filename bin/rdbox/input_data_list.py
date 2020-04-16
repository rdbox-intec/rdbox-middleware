#!/usr/bin/env python3
# coding: utf-8


class InputDataList(object):
    def __init__(self):
        self.input_list = []

    def add(self, input_data):
        self.input_list.append(input_data)
        return self

    def get_by_instance(self, instance):
        input_data_list = InputDataList()
        for input_data in self.input_list:
            if isinstance(input_data, instance):
                input_data_list.add(input_data)
        return input_data_list

    def get_list(self):
        return self.input_list
