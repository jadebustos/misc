#!/usr/bin/python

# (c) 2014 Jose Angel de Bustos Perez <jadebustos@gmail.com>

# Implementing switch case clause in python with dictionaries using strings

import sys


def main(args):

    # Using dictionaries to simulate switch case statement
    def johnaction():
        print "Hello John."

    def alanaction():
        print "Hellow Alan."

    def albertaction():
        print "Hellow Albert"

    # when John execute johnaction, Alan execute alanaction, Albert execute alabertaction
    options = {'John': johnaction,
        'Alan': alanaction,
        'Albert': albertaction,
        }

    # Doing switch case statement
    # To simulate the default switch case statement a try except clause has to be used
    try:
        options[args[1]]()
    except:
        print "Hellow unknown user " + args[1] + '.'

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print "It is mandatory to use one argument: John, Alan, Albert or others"
    else:
        main(sys.argv)