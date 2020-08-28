# -*- coding: utf-8 -*-
#!/usr/bin/python

# Copyright (C) 2015 Jose Angel de Bustos Perez <jadebustos@gmail.com>
# Distributed under GNU GPL v2 License
#   https://www.gnu.org/licenses/old-licenses/gpl-2.0.en.html

# Simple example of how to build a distributed and asynchronous application
# using Zeroc Ice 3.5.1 to be executed by Zeroc Ice Grid

# Client executes remotely salute_async() in asynchronous mode and detaches.
# Server waits a random interlval (from 2 to 5 seconds) and afther that
# notifies to the client a message.

# This script is the client side

# debug python HelloWorldClient.py --Ice.Trace.Network=2

import sys
import traceback
import Ice
import time
import random
import socket
import Glacier2
import json

Ice.loadSlice('HelloWorld.ice')

import Demo


class Callback(Ice.Object):
    def __init__(self, application):
        self.app_reference = application

    def response(self, return_str, out_str):
        print "Response received from " + out_str 

        fd = open("response.json", "w")
        fd.write(json.dumps(json.loads(return_str), indent=4))
        fd.close()
 
    def exception(self, ex):
        try:
                raise ex
        except Ice.LocalException, e:
                print "interpolate failed: " + str(e)
        except:
                try:
                        print "excepcion --- "
                except:
                    raise ex


class Client(Glacier2.Application):

    def createSession(self):
        session = None
        while True:
            try:
                session = self.router().createSession('grid', 'xxx')
                break
            except Glacier2.PermissionDeniedException as ex:
                print("permission denied:\n" + ex.reason)
            except Glacier2.CannotCreateSessionException as ex:
                print("cannot create session:\n" + ex.reason)
        return session

    def runWithSession(self, args):

        try:
	    
            ic = self.communicator()

            cb = Callback(self)

            myobj = Demo.HelloWorldPrx.checkedCast(ic.stringToProxy('AsyncGridReplyObj'))

            myobj.begin_salute(args[1], cb.response, cb.exception)

        except:
                traceback.print_exc()


myClient = Client()
sys.exit(myClient.main(sys.argv, "client.cfg"))
