all: sds-test Tsds-test

sds-test: sds.c sds.h testhelp.h sdsalloc.h
	$(CC) -o sds-test sds.c -Wall -std=c99 -pedantic -O2 -DSDS_TEST_MAIN
	@echo ">>> Type ./sds-test to run the sds.c unit tests."

clean: 
	rm -f sds-test
	rm -f Tsds.c
	rm -f Tsds.h
	rm -f Tsds.o
	rm -f Tsds.mh
	rm -f Tsds-test

Tsds.c: Tsds.mc
	../../bin/tmodc -a Tsds.mc -C	

Tsds: Tsds.c
	$(CC) -c Tsds.c -Wall -std=c11 -pedantic -O2

Tsds-test: Tsds.c testhelp.h
	$(CC) -o Tsds-test Tsds.c -Wall -std=c11 -pedantic -O2 -DSDS_TEST_MAIN
	@echo ">>> Type ./Tsds-test to run the Tsds.c unit tests."
