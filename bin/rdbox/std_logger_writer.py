#!/usr/bin/env python3
# coding: utf-8

import sys

class StdLoggerWriter:
    def __init__(self, level):
        # self.level is really like using log.debug(message)
        # at least in my case
        self.level = level

    def write(self, message):
        # if statement reduces the amount of newlines that are
        # printed to the logger
        for line in message.rstrip().splitlines():
            self.level(line)

    def flush(self):
        # create a flush method so things can be flushed when
        # the system wants to. Not sure if simply 'printing'
        # sys.stderr is the correct way to do it, but it seemed
        # to work properly for me.
        if not isinstance(sys.stderr, StdLoggerWriter):
            self.level(sys.stderr)
