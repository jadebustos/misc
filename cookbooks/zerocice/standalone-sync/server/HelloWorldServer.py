# -*- coding: utf-8 -*-
#!/usr/bin/python

# Copyright (C) 2015 Jose Angel de Bustos Perez <jadebustos@gmail.com>
# Distributed under GNU GPL v2 License
#   https://www.gnu.org/licenses/old-licenses/gpl-2.0.en.html

# Simple example of how to build a distributed and synchronous application
# using Zeroc Ice 3.5.1 to be executed manually

# When HelloWorkdI.salute() is remotely executed "Hello World!!" will be
# printed in the stdout


# This script is the server side

import sys, traceback, Ice

Ice.loadSlice('HelloWorld.ice')
import Demo


class HelloWorldI(Demo.HelloWorld):

    def __init__(self):
        self.msg = "Hello World!!\n"

    def salute(self, current=None):
        print self.msg


class Server(Ice.Application):

    def run(self, args):

        self.callbackOnInterrupt()
        adapter = self.communicator().createObjectAdapter("StandaloneSync")

        adapter.add(HelloWorldI(), self.communicator().stringToIdentity("StandaloneSyncObject"))

        adapter.activate()

        self.communicator().waitForShutdown()

        self.communicator.gracefulShutdown()

        return 0

myServer = Server()
sys.exit(myServer.main(sys.argv, "config.server"))
