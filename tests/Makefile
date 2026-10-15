# Standalone package tree. tests/ is the project root.
# 	make -C tests
# 	make -C tests run
# 	make -C tests clean

HERE 	:= $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
TMODC 	:= $(HERE)/../bin/tmodc
CC 		?= gcc
CFLAGS 	:= -std=c11 -Wall -Wextra

PROG 	:= test_Strings
PROG_MC	:= $(HERE)/tmodc/tests/$(PROG).mc
PROG_C 	:= $(HERE)/tmodc/tests/$(PROG).c
PROG_H	:= $(HERE)/tmodc/tests/$(PROG).h

BIN_DIR	:= $(HERE)/bin
BIN 	:= $(BIN_DIR)/$(PROG)

LIB_DIR 	:= $(HERE)/tmodc/lib
LIB_MCS 	:= $(sort $(wildcard $(LIB_DIR)/*.mc))
LIB_CS 		:= $(LIB_MCS:.mc=.c)
LIB_HS 		:= $(LIB_MCS:.mc=.h)
LIB_MHS 	:= $(LIB_MCS:.mc=.mh)

.PHONY: all run clean

all: $(BIN)

# Onetmodc run per library writes that stem's .c, .h, and .mh
$(LIB_DIR)/%c $(LIB_DIR)/%.h $(LIB_DIR)/%.mh: $(LIB_DIR)/%.mc $(TMODC)
		$(TMODC) $< -C

$(PROG_C) $(PROG_H) &: $(PROG_MC) $(LIB_MHS) $(TMODC)
	$(TMODC) $(PROG_MC) -C

$(BIN): $(PROG_C) $(LIB_CS) $(PROG_H) $(LIB_HS) | $(BIN_DIR)
		$(CC) $(CFLAGS) -o $(BIN) $(PROG_C) $(LIB_CS)

$(BIN_DIR):
	mkdir -p $(BIN_DIR)

run: $(BIN)
	$(BIN)

clean:
	rm -f $(LIB_CS) $(LIB_HS) $(LIB_MHS) $(PROG_C) $(PROG_H) $(BIN)
