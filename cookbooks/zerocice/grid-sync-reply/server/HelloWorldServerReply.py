# -*- coding: utf-8 -*-
#!/usr/bin/python

# Copyright (C) 2015 Jose Angel de Bustos Perez <jadebustos@gmail.com>
# Distributed under GNU GPL v2 License
#   https://www.gnu.org/licenses/old-licenses/gpl-2.0.en.html

# Simple example of how to build a distributed and synchronous application
# using Zeroc Ice 3.5.1 to be executed by Zeroc Ice Grid

# Server returns its hostname and it will be printed in client's stdout

# This script is the server side

# debug python HelloWorldServer.py --Ice.Trace.Network=2

import sys, traceback, Ice
import socket

Ice.loadSlice('HelloWorld.ice')
import Demo


class HelloWorldI(Demo.HelloWorld):

    def __init__(self):
        self.hostname = socket.gethostname()

    def salute(self, current=None):
        fd = open("/tmp/grid.stdout", "a")
        fd.write(self.hostname)
        fd.close()
        return self.hostname


class Server(Ice.Application):

    def run(self, args):

        self.callbackOnInterrupt()
        adapter = self.communicator().createObjectAdapter("SyncGridReplyAdp")

        adapter.add(HelloWorldI(), self.communicator().stringToIdentity("SyncGridReplyObj"))

        adapter.activate()

        self.communicator().waitForShutdown()

        self.communicator.gracefulShutdown()

        return 0

myServer = Server()
sys.exit(myServer.main(sys.argv))
