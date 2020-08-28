#/usr/bin/python

import traceback
import json
import sys


def main(args):
    data = {}
    hostnames = []
    ips = []
    try:
        fd = open(args[1], "r")
        data = json.load(fd)
        fd.close()
    except:
        print "error"

    for client in data.keys():
        for type in data[client].keys():
            my_object = data[client][type]
            for group in my_object.keys():
                start = int(my_object[group]['start'])
                end = int(my_object[group]['end'])
                ipv4start = int(my_object[group]['ipv4start'])
                ipv4end = int(my_object[group]['ipv4end'])
                network = my_object[group]['network']
                # hostnames
                for i in range(start, end + 1):
                    hostnames.append(client + "-" + type + "-" + str(i))
                # ips
                for i in range(ipv4start, ipv4end + 1):
                    ips.append(network + str(i))
                # fqdns
                if "fqdn" in my_object[group]:
                    for i in my_object[group]['fqdn']:
                        hostnames.append(my_object[group]['fqdn'][i])
                        ips.append(network + str(i))

    for item in range(0, len(hostnames)):
        print ips[item] + " " + hostnames[item]

if __name__ == "__main__":
    main(sys.argv)


