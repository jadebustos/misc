#!/usr/bin/python

import socket
import random

def client(string):
    HOST, PORT = 'localhost', 21212
    # SOCK_STREAM == a TCP socket
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    #sock.setblocking(0)  # optional non-blocking
    sock.connect((HOST, PORT))

    print "sending data => [%s]" % (string)

    sock.send(string)
    reply = sock.recv(16384)  # limit reply to 16K
    print "reply => \n [%s]" % (reply)
    sock.close()
    return reply

def main():
    client('Python Rocks')

if __name__ == "__main__":
    main()
