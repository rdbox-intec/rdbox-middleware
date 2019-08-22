#!/usr/bin/env python3
# coding: utf-8


class K8sResponseExternal(object):
    def __init__(self, org_response, hostname, ip, location):
        self.org_response = org_response
        self.hostname = hostname
        self.ip = ip
        self.location = location

    def __repr__(self):
        return "<K8sResponseExternal '%s' : '%s' : '%s'>" % (self.hostname, self.ip, self.location)

    def get_hostname(self):
        return self.hostname

    def get_ip(self):
        return self.ip

    def get_location(self):
        return self.location
