#!/usr/bin/python

# (c) 2014 Jose Angel de Bustos Perez <jadebustos@gmail.com>

# Implementing switch case clause in python with dictionaries using integers

import sys


def main(args):

    # Using dictionaries to simulate switch case statement
    def zero():
        print "Zero."

    def one():
        print "One."

    def two():
        print "Two"

    # when 0 execute zero, 1 execute one, 2 execute two
    options = {0: zero,
        1: one,
        2: two,
        }

    # Doing switch case statement
    # To simulate the default switch case statement a try except clause has to be used
    try:
        options[int(args[1])]()
    except:
        print "Unknown number " + args[1] + '.'

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print "It is mandatory to use numbers: 0, 1, 2, ..."
    else:
        main(sys.argv)