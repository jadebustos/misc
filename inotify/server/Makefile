CC=gcc
CFLAGS=-g

all: proc-args.o read-config.o inotify.o mysignal.o finish.o
	$(CC) mft-in.c proc-args.o read-config.o inotify.o mysignal.o finish.o -o mft-in -lconfig

proc-args:
	$(CC) -c proc-args.c

read-config:
	$(CC) -c read-config.c

inotify:
	$(CC) -c inotify.c

mysignal:
	$(CC) -c mysignal.c

finish:
	$(CC) -c finish.c

clean:
	rm -f *.o *~ mft-in
