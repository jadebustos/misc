# TSAMP automation scripts

## Copyright

This software is licensed under GPLv2: http://www.gnu.org/licenses/gpl-2.0.html
  
  (c) 2013 Jose Angel de Bustos Perez <jadebustos@gmail.com>

## Introduction

These scripts install IBM Tivoly System Automation for Multiplatforms (TSAMP) and configure cluster resources. It was developed and tested with TSAMP versions 3.2.x.

Requirements:

* TSAM nodes installed and configured to be reachable by network and SSH.
* DNS resolution.
* Public key authentication between/among TSAM nodes with root users, including
  the node where the script is executed that must be able to login itself via
  ssh.
* Application must be installed in all TSAM nodes.
* Application must be able to start/stop/monitor in all TSAM nodes.
* Application scripts must be TSAM compliance (return codes).
* Application scripts/files paths must be the same across TSAM nodes.
* Application data must be on LVM volume groups inside a disk partition.
* Application filesystems must be unmouted in all TSAM nodes.
* Application filesystems must have its mount points in /etc/fstab including noauto option.
* Application must be stopped in all TSAM nodes.
* Network interfaces are configured in a symmetric way across the nodes.
* Network addresses need to be /8, /16 or /24. This is due to these scripts need to detect the network interface in which the VIP has to be configured without human intervention and no additional software are allowed to be installed. If you are using subnetting these scripts will not work properly. In that case you should ckeck **tsam_network_rsrc** function in **app2tsam-config-rsrc.sh** script.

## Scripts

The following scripts are supplied:

* **app2tsam-install-tsam.sh**, script to install and configure TSAMP.
* **app2tsam-config-rsrc.sh**, script to configure cluster resources.
* **app2tsam-get_data.sh**, bash dialog script which ask information to generate configuration files.
* **db2_cluster_name-3.2.1-FP3.conf**, configuration file to cluster DB2 using TSAMP 3.2.1 FP3.
* **db2_cluster_name-3.2.2-FP3.conf**, configuration file to cluster DB2 using TSAMP 3.2.2 FP3.

## How to use

The first thing to do is install the application on both nodes (or serveral) and get the application running in standalone mode on each cluster node. After that, a configuration file is needed.

**db2_cluster_name-3.2.1-FP3.conf** and **db2_cluster_name-3.2.1-FP3.conf** are two examples of configuration files for DB2. You can write it by hand or you can use the bash dialog script **app2tsam-get_data.sh** to generate the configuration file.

Once the configuration file has been generated you will need to run **app2tsam-install-tsam.sh** in only one node to get TSAMP installed on all the nodes. Network tiebreaker and heartbeat disk will be configured.

TSAMP binary file should be in the node where the install script will be executed and TSAMP license as well.

To run the script the configuration file has to be supplied as first argument:
```
[user@localhost ~]$ bash app2tsam-install-tsam.sh db2_cluster_name-3.2.2-FP3.conf
```

After TSAMP is installed and configured in all the nodes you will need to configure cluster resources, so you will need to run **app2tsam-config-rsrc.sh** in only one node:
```
[user@localhost ~]$ bash app2tsam-config-rsrc.sh db2_cluster_name-3.2.2-FP3.conf
```

Logs will be write to **/var/log/tsam-installation.log** (LOG_FILE variable).

## Disclaimer

These scripts were developed to fit my needs and could not fit yours.

