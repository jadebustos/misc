inotify client example
======================

# Description

This is a simple example to create files quickly in a directory using several threads with OpenMP.

# Compiling

```
make all
```

# Executing

This example uses 4 threas to create 4000 files under /tmp/mft-in/files:

```
./mft-out --threads 4 --number 4000 --directory /tmp/mft-in/files/
```
