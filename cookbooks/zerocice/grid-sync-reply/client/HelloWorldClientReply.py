# -*- coding: utf-8 -*-
#!/usr/bin/python

# Copyright (C) 2015 Jose Angel de Bustos Perez <jadebustos@gmail.com>
# Distributed under GNU GPL v2 License
#   https://www.gnu.org/licenses/old-licenses/gpl-2.0.en.html

# Simple example of how to build a distributed and synchronous application
# using Zeroc Ice 3.5.1 to be executed by Zeroc Ice Grid

# Server returns its hostname and it will be printed in client's stdout

# This script is the client side

# debug python HelloWorldClient.py --Ice.Trace.Network=2

import sys, traceback, Ice

Ice.loadSlice('HelloWorld.ice')

import Demo


class Client(Ice.Application):

    def __init__(self):
        ic = None

    def run(self,  args):

        try:
            ic = self.communicator()

            myobj = Demo.HelloWorldPrx.checkedCast(ic.stringToProxy('SyncGridReplyObj'))

            reply = myobj.salute()

            print "Reply: " + reply

        except:
                traceback.print_exc()

        if ic:
            # clean up
            try:
                ic.destroy()
            except:
                traceback.print_exc()


myClient = Client()
sys.exit(myClient.main(sys.argv, "client.cfg"))
