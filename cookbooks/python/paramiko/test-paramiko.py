# -*- coding: utf-8 -*-
#!/usr/bin/python

import paramiko

# Paramiko client configuration
# enable GSS-API / SSPI authentication
UseGSSAPI = True
DoGSSAPIKeyExchange = True
port = 22

ssh = paramiko.SSHClient()
ssh.load_system_host_keys()

ssh.connect('pos1.jadbp.lab', username='root')

ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())

stdin, stdout, stderr = ssh.exec_command("/root/error.py")

mystderr = stderr.readlines()

print mystderr

print "--"

print stdout.channel.recv_exit_status()