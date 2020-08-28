# -*- coding: utf-8 -*-
#!/usr/bin/python

# Copyright (C) 2015 Jose Angel de Bustos Perez <jadebustos@gmail.com>
# Distributed under GNU GPL v2 License
#   https://www.gnu.org/licenses/old-licenses/gpl-2.0.en.html

# Simple example of how to build a distributed and asynchronous application
# using Zeroc Ice 3.5.1 to be executed by Zeroc Ice Grid

# Client executes remotely salute_async() in asynchronous mode and detaches.
# Server waits a random interlval (from 2 to 5 seconds) and afther that
# notifies to the client a message: 
#   "Hello, this is server_hostname. Waiting time: XX seconds"

# This script is the server side

# debug python HelloWorldServer.py --Ice.Trace.Network=2

import sys
import Ice
import socket
import json

Ice.loadSlice('HelloWorld.ice')
import Demo


class HelloWorldI(Demo.HelloWorld):

    def __init__(self):
        self.mydict = {}
        self.hostname = socket.gethostname()
        

    def salute_async(self, cb, filename, current=None):
        fd = open(filename, "r")
        filedata = fd.read()
        fd.close()
        self.mydict['data'] = json.loads(filedata)
        fd = open("/tmp/debug.json", "w")
        fd.write(filedata)
        fd.close()
        fd = open("/tmp/debug-dict.json", "w")
        fd.write(json.dumps(self.mydict['data'], indent=4))
        fd.write(self.hostname)
        fd.close()
        cb.ice_response(json.dumps(self.mydict['data']), self.hostname)


class Server(Ice.Application):

    def run(self, args):

        self.callbackOnInterrupt()
        adapter = self.communicator().createObjectAdapter("AsyncGridReplyAdp")

        adapter.add(HelloWorldI(), self.communicator().stringToIdentity("AsyncGridReplyObj"))

        adapter.activate()

        self.communicator().waitForShutdown()

        return 0

myServer = Server()
sys.exit(myServer.main(sys.argv))
