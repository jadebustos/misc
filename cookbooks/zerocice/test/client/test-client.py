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

Ice.loadSlice('test.ice')

import Demo


class Callback(Ice.Object):
    def __init__(self, application):
        self.app_reference = application

    def response(self, return_str, out_str):
        print "From " + out_str + ": " + return_str

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


class Client(Ice.Application):

    def __init__(self):
        pass

    def run(self, args):

        try:
            ic = self.communicator()

            cb = Callback(self)

            myobj = Demo.HelloWorldPrx.checkedCast(ic.stringToProxy('AsyncGridReplyObj'))
            print args[0]
            myobj.begin_salute(args[0], cb.response, cb.exception)

            print "This is " + self.hostname + ". Sleeping for " + str(self.timer) + " seconds."
            print "*****"
            print "*****"
            time.sleep(self.timer)
            print "*****"
            print "*****"
            print "This is " + self.hostname + ". Back online."

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
