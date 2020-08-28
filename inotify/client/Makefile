CC=gcc
CFLAGS=-g

all: proc-args.o 
	$(CC) mft-out.c proc-args.o -o mft-out

proc-args:
	$(CC) -c proc-args.c

clean:
	rm -f *.o *~ mft-in
