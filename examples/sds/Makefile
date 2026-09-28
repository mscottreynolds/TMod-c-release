all: sds.c sds-test

sds-test: sds.c sds.h testhelp.h sdsalloc.h
	$(CC) -o sds-test sds.c -Wall -std=c99 -pedantic -O2 -DSDS_TEST_MAIN
	@echo ">>> Type ./sds-test to run the sds.c unit tests."

clean: 
	rm -f sds-test
	rm -f Tsds.c
	rm -f Tsds.h
	rm -f Tsds.o
	rm -f Tsds.mh

Tsds:
	../../bin/tmodc -a Tsds.mc -C
	$(CC) -c Tsds.c -Wall -std=c11 -pedantic -O2

Tsds-test:
	../../bin/tmodc -a Tsds.mc -C
	$(CC) -o Tsds-test Tsds.c -Wall -std=c11 -pedantic -O2 -DSDS_TEST_MAIN
