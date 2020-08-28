inotify server example
======================

# Description

This is a simple example to use inotify kernel mechanism to monitor a directory to launch a script on file creation.

This example uses a blocking function, read, so it could be a good idea to chante to use select, poll or epoll or even use a multithreaded version to be able to manage multiple file creation at the same time rightly.

Log service is not implemented.

The command which is executed on file creation is executed with the file as first argument.

# Configuration file

```
# pid file
pid = "/var/run/mft-in.pid"

# log system
# log_service = 0 syslog is used
# log_service = 1 systemd is used
log_service = 0

# directory to be monitored
directory = "/tmp/mft-in/files"

# event to be monitored
# 0 - file creation
event = 0

# command to be triggered
cmd = "/path/to/command/test-inotify.sh"
```

# Compiling

```
make all
```

# Executing

```
./mft-in --config-file mft-in.conf
```