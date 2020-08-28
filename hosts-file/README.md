# Generating host entries

This script prints in stdout a list of ips and hosts to populate **/etc/hosts** file taken the data from a json file which needs to be passed as the script's first argument.

This script is useful when you need to use your **/etc/hosts** file as a resolver.

If your servers can be grouped by role and their ips are sequential in most cases this script can be useful.

An example of the **json data file** can be downloaded from [here](data-example.json).

```
$ python generate-hosts-entries.py data-example.json 
192.168.170.61 client-haproxy-1
192.168.170.62 client-haproxy-2
192.168.170.63 client-haproxy-3
192.168.180.11 client-ceph-admin-1
192.168.180.11 client-ceph-admin-2
192.168.190.11 client-az01-compute-1
192.168.190.12 client-az01-compute-2
192.168.190.13 client-az01-compute-3
192.168.200.65 client-vip-1
192.168.200.66 client-vip-2
192.168.200.67 client-vip-3
192.168.200.68 client-vip-4
192.168.200.69 client-vip-5
192.168.200.70 client-vip-6
192.168.200.70 horizon.mylab.com
192.168.170.11 client-controller-1
192.168.170.12 client-controller-2
192.168.170.13 client-controller-3
192.168.170.21 client-controller-4
192.168.170.22 client-controller-5
192.168.170.23 client-controller-6
192.168.200.11 client-az02-compute-1
192.168.200.12 client-az02-compute-2
192.168.200.13 client-az02-compute-3
192.168.170.51 client-backend-1
192.168.170.52 client-backend-2
192.168.170.53 client-backend-3
$
```
