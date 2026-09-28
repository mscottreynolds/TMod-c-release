# Makefile for a TMod-c version of kilo, a simple text editor from tutorial at:
# https://viewsourcecode.org/snaptoken/kilo/index.html

TMODC=../../bin/tmodc
TARGET=kilo

# feature test macros
CFLAGS += -D_DEFAULT_SOURCE -D_BSD_SOURCE -D_GNU_SOURCE

.PHONY: all kilo read_key run clean

kilo: kilo.c
	$(CC) $(CFLAGS) kilo.c -o kilo -Wall -Wextra -pedantic -std=c11

kilo.c: kilo.mc
	$(TMODC) -q kilo.mc -C

run: kilo
	@./kilo

read_key: read_key.c
	$(CC) $(CFLAGS) read_key.c -o read_key -Wall -Wextra -pedantic -std=c11

read_key.c: read_key.mc
	$(TMODC) -q read_key.mc -C

clean:
	@rm -vf kilo
	@rm -vf kilo.c
	@rm -vf kilo.h
	@rm -vf read_key
	@rm -vf read_key.c
	@rm -vf read_key.h

all: kilo read_key

# msr/msr
