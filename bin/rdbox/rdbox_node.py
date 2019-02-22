#!/usr/bin/env python3
# coding: utf-8


class RdboxNode(object):
    def __init__(self, hostname, ip, location):
        self.hostname = hostname
        self.ip = ip
        self.location = location

    def __repr__(self):
        return "<RdboxNode '%s' : '%s' : '%s'>" % (self.hostname, self.ip, self.location)

    def get_hostname(self):
        return self.hostname

    def get_ip(self):
        return self.ip

    def get_location(self):
        return self.location

