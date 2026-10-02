# Makefile for Mod-c, a C, Pascal, Modula-2, Oberon inspired compiler.

VERSION 	:= 0.26.9

BIN_DIR   	= bin
SRC_DIR   	= src
LIB_DIR		= lib
INCLUDE_DIR = include
BUILD_DIR 	= build
C_BUILD_DIR	= $(BUILD_DIR)/c
TEST_DIR  	= tests
TEST_BUILD_DIR = $(BUILD_DIR)/test
DIST_DIR  	= dist
DOC_DIR   	= docs
TARGET    	= $(BIN_DIR)/modc.$(VERSION)
INSTALL_DIR = /opt/tmodc
EXAMPLES_DIR = examples

BUILD_FILE   := $(SRC_DIR)/build.number
BUILD_NUMBER := $$(cat $(BUILD_FILE) 2>/dev/null || echo 0)

SOURCES = $(wildcard $(SRC_DIR)/*.c)
OBJS    = $(patsubst $(SRC_DIR)/%c,$(C_BUILD_DIR)/%o,$(SOURCES))

# Host C compiler: gcc (default), clang, or tcc.
# 	make
# 	make CC=clang
# 	make CC=tcc
# Re-run `make clean` after changing CC so objects in $(C_BUILD_DIR) are not mixed.
# `clang-18` / `gcc-14` / full paths are classified via CC_FAMILY.
CC ?= gcc

ifeq ($(findstring clang,$(CC)),clang)
CC_FAMILY := clang
else ifeq ($(findstring tcc,$(CC)),tcc)
CC_FAMILY := tcc
else
CC_FAMILY := gcc
endif

CFLAGS_INCLUDES = -I$(SRC_DIR) -I$(INCLUDE_DIR) -I$(LIB_DIR)

ifeq ($(CC_FAMILY),tcc)
# From Makefile.tcc: no -pedantic-errors / -Wconversion; has -Wswitch-enum
CFLAGS = -std=c11 -Wall -Wextra -O2 \
	-Wshadow -Wundef -Wstrict-prototypes -Wmissing-prototypes \
	-Wpointer-arith -Wwrite-strings -Wcast-qual \
	-Wswitch-enum -Wstrict-overflow=4 $(CFLAGS_INCLUDES)
DEBUG_FLAGS = -g -O0
else ifeq ($(CC_FAMILY),clang)
# FROM Makefile.clang: no -Wcast-align=strict (GCC-only).
CFLAGS = -std=c11 -pedantic-errors -Wall -Wextra -Wconversion -O2 \
	-Wshadow -Wundef -Wstrict-prototypes -Wmissing-prototypes \
	-Wpointer-arith -Wwrite-strings -Wcast-qual \
	-Wstrict-overflow=4 $(CFLAGS_INCLUDES)
#	-Wswitch-enum
DEBUG_FLAGS = -g -O0 -fsanitize=address
else
# gcc (default)
CFLAGS = -std=c11 -pedantic-errors -Wall -Wextra -Wconversion -O2 \
	-Wpointer-arith -Wwrite-strings -Wcast-qual -Wcast-align=strict \
	-Wstrict-overflow=4 $(CFLAGS_INCLUDES)
# 	-Wswitch-enum
DEBUG_FLAGS = -g -O0 -fsanitize=address
endif

# All matching type 1 test source files.
TEST_MC_FILES := $(wildcard $(TEST_DIR)/test_*.mc)

# Basenames without .mc extension.
TEST_NAMES := $(basename $(notdir $(TEST_MC_FILES)))

# All matching type 2 test files.
TEST2_MC_FILES := $(wildcard $(TEST_DIR)/test2_*.mc)

# All matching type 3 test files.
TEST3_MC_FILES := $(wildcard $(TEST_DIR)/test3_*.mc)

# All Mod-C source files (*.mc) in src/ (for self-host testing)
SRC_MC_FILES := $(wildcard $(SRC_DIR)/*.mc)

# Selfhost destination directory for building files.
SH_BUILD_DIR := $(BUILD_DIR)/selfhost

# Bootstrap build directory.
BS_BUILD_DIR := $(BUILD_DIR)/bootstrap

TAR_NAME	:= "tmod-c-$(VERSION).$(BUILD_NUMBER)"
TAR_DIR 	:= $(BUILD_DIR)/$(TAR_NAME)

# -----------------------------------------------------------
# Small test library: String + StringBuffer (from tests/*.mc)
# -----------------------------------------------------------
LIB_BUILD_DIR 	= $(BUILD_DIR)/lib
LIB_MODULES 	= String StringBuffer Integer Cardinal Real
LIB_NAME 		= tmod_string
LIB_ARCHIVE 	= $(LIB_DIR)/lib$(LIB_NAME).a

# Generated per module: .c in build/lib, .h/.mh in include, .o in lib
LIB_MC_FILES 	= $(addprefix $(TEST_DIR)/,$(addsuffix .mc,$(LIB_MODULES)))
LIB_C_FILES 	= $(addprefix $(LIB_BUILD_DIR)/,$(addsuffix .c,$(LIB_MODULES)))
LIB_H_FILES 	= $(addprefix $(INCLUDE_DIR)/,$(addsuffix .h,$(LIB_MODULES)))
LIB_MH_FILES 	= $(addprefix $(INCLUDE_DIR)/,$(addsuffix .mh,$(LIB_MODULES)))
LIB_O_FILES 	= $(addprefix $(LIB_DIR)/,$(addsuffix .o,$(LIB_MODULES)))


# -------------------------------------------------------

all: $(TARGET)

# Increment BUILD_NUMBER and update src/version.h
version:
	@build=$$(cat $(BUILD_FILE) 2>/dev/null || echo 0);			\
	build=$$((build + 1)); 										\
	echo $$build > $(BUILD_FILE); 								\
	printf '%s\n'												\
		'// DO NOT EDIT: This is generated via the Makefile' 	\
		"#define VERSION \"$(VERSION).$$build\"" 				\
		"#define VERSION_BASE \"$(VERSION)\""					\
		"#define BUILD_NUMBER $$build"							\
		> $(SRC_DIR)/version.h
	@echo VERSION=$(VERSION)
	@echo BUILD_NUMBER=$$(cat $(BUILD_FILE) 2>/dev/null || echo 0)

info:
	@echo VERSION=$(VERSION)
	@echo BUILD_NUMBER=$(BUILD_NUMBER)
	@echo BIN_DIR=$(BIN_DIR)
	@echo SRC_DIR=$(SRC_DIR)
	@echo BUILD_DIR=$(BUILD_DIR)
	@echo C_BUILD_DIR=$(C_BUILD_DIR)
	@echo TEST_DIR=$(TEST_DIR)
	@echo TEST_BUILD_DIR=$(TEST_BUILD_DIR)
	@echo DIST_DIR=$(DIST_DIR)
	@echo DOC_DIR=$(DOC_DIR)
	@echo TARGET=$(TARGET)
	@echo SOURCES=$(SOURCES)
	@echo OBJS=$(OBJS)
	@echo CC_FAMILY=$(CC_FAMILY)
	@echo CC=$(CC)
	@echo CFLAGS=$(CFLAGS)
	@echo DEBUG_FLAGS=$(DEBUG_FLAGS)
	@echo SRC_MC_FILES=$(SRC_MC_FILES)
	@echo TEST_NAMES=$(TEST_NAMES)
	@echo TEST_MC_FILES=$(TEST_MC_FILES)
	@echo TEST2_MC_FILES=$(TEST2_MC_FILES)
	@echo TEST3_MC_FILES=$(TEST3_MC_FILES)

# Link the executable
$(TARGET): $(OBJS) | $(BIN_DIR)
	$(CC) $(OBJS) -o $(TARGET)

$(BIN_DIR): $(BUILD_DIR)
	mkdir -p $(BIN_DIR)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# Compile source files from src/ to build/c
$(C_BUILD_DIR)/%.o: $(SRC_DIR)/%.c | $(C_BUILD_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

# Create build directory of needed
$(C_BUILD_DIR): 
	mkdir -p $(C_BUILD_DIR)


# tmodc script
tmodc: all
	@sed \
	    -e 's|@VERSION@|$(VERSION)|g' \
	    -e 's|@INSTALL_DIR@|$(INSTALL_DIR)|g' \
	    tmodc.sh.in > $(BIN_DIR)/$@
	@chmod +x $(BIN_DIR)/$@
	@echo "Ready: $(BIN_DIR)/$@"

# Source archive
tar:
	@echo Creating $(TAR_NAME).tgz
	@mkdir -p $(TAR_DIR)
	@mkdir -p $(TAR_DIR)/docs
	@mkdir -p $(TAR_DIR)/examples
	@mkdir -p $(TAR_DIR)/src
	@mkdir -p $(TAR_DIR)/tests
	@cp -v changelog.md ${TAR_DIR}
	@cp -v CURRENT.md ${TAR_DIR}
	@cp -v hello.mc $(TAR_DIR)
	@cp -v LICENSE.md ${TAR_DIR}
	@cp -v Makefile $(TAR_DIR)
	@cp -v README.md ${TAR_DIR}
	@cp -v tmodc.sh.in $(TAR_DIR)
	@cp -v $(DOC_DIR)/syntax-ebnf.md $(TAR_DIR)/docs
	@cp -v $(DOC_DIR)/language-report.md $(TAR_DIR)/docs
	@cp -v $(DOC_DIR)/parameter-passing.md $(TAR_DIR)/docs
	@cp -Rv $(EXAMPLES_DIR) $(TAR_DIR)
	@cp -Rv $(INCLUDE_DIR) $(TAR_DIR)
	@cp -Rv $(LIB_DIR) $(TAR_DIR)
	@cp -Rv $(SRC_DIR) $(TAR_DIR)
	@cp -Rv $(TEST_DIR) $(TAR_DIR)
	@tar czvf "$(BUILD_DIR)/$(TAR_NAME).tgz" -C $(BUILD_DIR) "$(TAR_NAME)"
	@echo "Ready: $(BUILD_DIR)/$(TAR_NAME).tgz"

# Distribution directory. Run all tests first.
dist: test-all tmodc
	@mkdir -p ${DIST_DIR}
	@cp -v ${TARGET} ${DIST_DIR}
	@cp -v ${BIN_DIR}/tmodc ${DIST_DIR}/tmodc
	@cp -v ${DOC_DIR}/syntax-ebnf.md ${DIST_DIR}/grammar.md
	@cp -v ${DOC_DIR}/language-report.md ${DIST_DIR}
	@cp -v README.md ${DIST_DIR}
	@cp -v LICENSE.md ${DIST_DIR}
	@echo "Dist complete"

# Install into INSTALL_DIR
install:
	@mkdir -p $(INSTALL_DIR)
	@cp -v ${DIST_DIR}/modc.${VERSION} ${INSTALL_DIR}/
	@chmod +x ${INSTALL_DIR}/modc.${VERSION}
	@cp -v ${DIST_DIR}/grammar.md ${INSTALL_DIR}
	@cp -v ${DIST_DIR}/README.md ${INSTALL_DIR}
	@cp -v ${DIST_DIR}/LICENSE.md ${INSTALL_DIR}
	@cp -v ${DIST_DIR}/tmodc ${INSTALL_DIR}/tmodc
	@chmod +x ${INSTALL_DIR}/tmodc
	@echo "Install complete"

# Uninstall from INSTALL_DIR
uninstall:
	@rm -v ${INSTALL_DIR}/modc
	@rm -v ${INSTALL_DIR}/modc.${VERSION}
	@rm -v ${INSTALL_DIR}/grammar.md
	@rm -v ${INSTALL_DIR}/README.md
	@rm -v ${INSTALL_DIR}/LICENSE.md
	@rmdir ${INSTALL_DIR}
	@echo "uninstall complete"

# Debug target (overrids CFLAGS)
debug: CFLAGS += $(DEBUG_FLAGS)
debug: $(OBJS) | $(BIN_DIR)
	$(CC) $(CFLAGS) $(OBJS) -o $(TARGET)

test-all: test test2 test3

# Test AST and semantic analysis
test: $(TARGET)
	@mkdir -p $(TEST_BUILD_DIR)
	@echo "=== Running type 1 tests (test_*) ==="
	@total=0; fail=0;															\
	for name in $(TEST_NAMES); do 												\
		src="$(TEST_DIR)/$$name.mc"; 											\
		c_file="$(TEST_BUILD_DIR)/$$name.c"; 									\
		h_file="$(TEST_BUILD_DIR)/$$name.h";									\
		exec="$(BIN_DIR)/$$name"; 												\
		total=$$((total + 1));													\
		echo "[$$total]\t$$src ";												\
		if [ ! -f "$${src}" ]; then 											\
			fail=$$((fail + 1));												\
			echo "FAIL (file not found)";										\
			continue;															\
		fi;																		\
		if ! ./$(TARGET) "$$src" -C "$$c_file" -H "$$h_file" >/dev/null; then	\
			fail=$$((fail + 1));												\
			echo "FAIL (modc)";													\
			continue; 															\
		fi; 																	\
		if ! $(CC) $(CFLAGS) -o "$$exec" "$$c_file" >/dev/null 2>&1; then		\
			fail=$$((fail + 1));												\
			echo "FAIL (cc)";													\
			continue;															\
		fi;																		\
		if ! "$$exec" >/dev/null; then											\
			fail=$$((fail + 1));												\
			echo "FAIL (run exit $$?)";											\
		else																	\
			: ;																	\
		fi;																		\
	done;																		\
	echo "=== Type 1: $$total run, $$fail failed ===";							\
	test $$fail -eq 0
	@$(BIN_DIR)/test_Pi 1000 -f > $(TEST_BUILD_DIR)/test_Pi.out
	@echo -n "=== test_Pi diff "
	@diff -uw $(TEST_BUILD_DIR)/test_Pi.out $(TEST_DIR)/test_Pi_1000.txt ||		\
		(echo "FAILED ===" && exit 1)
	@echo "OK ==="
	@echo "=== All tests completed. ==="

# Build and run type 2 tests
test2: $(TARGET) 
	@echo "=== Running type 2 (test2_*) tests ==="
	@total=0; fail=0;										\
	for f in $(TEST2_MC_FILES); do 							\
		total=$$((total + 1));								\
		echo -n "[$$total] $$f ";							\
		if ./$(TARGET) -a "$$f" >/dev/null; then 			\
			echo ""; 										\
		else 												\
			fail=$$((fail + 1));							\
			echo "\tFAIL (expected success)";				\
		fi;													\
	done;													\
	echo "=== Type 2: $$total run, $$fail failed ===";		\
	test $$fail -eq 0

test3: $(TARGET)
	@echo "=== Running type 3 tests (test3_* - expect semantic failure) ==="
	@total=0; fail=0;										\
	for f in $(TEST3_MC_FILES); do 							\
		total=$$((total + 1));								\
		echo -n "[$$total] $$f ";							\
		if ./$(TARGET) -a "$$f" >/dev/null 2>&1; then		\
			fail=$$((fail + 1)); 							\
			echo "FAIL (compiled when error expected)";		\
		else												\
			echo "";										\
		fi;													\
	done;													\
	echo "=== Type 3: $$total run, $$fail failed ===";		\
	test $$fail -eq 0

run: $(TARGET)
	@( 																				\
	if [ -z "$(FILE)" ]; then echo "Usage: make run FILE=hello.mc"; exit 1; fi; 	\
	if [ ! -f "$(FILE)" ]; then echo "File not found: $(FILE)"; exit 1; fi; 		\
	echo "=== running $(FILE) ===";													\
	src="$(basename $(notdir $(FILE)))";											\
	c_file="$(BUILD_DIR)/$${src}.c";												\
	h_file="$(BUILD_DIR)/$${src}.h";												\
	obj="$(BUILD_DIR)/$${src}.o";													\
	exe="$(BIN_DIR)/$${src}";														\
	$(TARGET) "$(FILE)" -C "$${c_file}" -H "$${h_file}" || exit 1;					\
	$(CC) $(CFLAGS) -o "$(BIN_DIR)/$${src}" "$(BUILD_DIR)/$${src}.c" || exit 1;		\
	$(BIN_DIR)/$${src};																\
	)


# ==========================================================
# Test library:String + StringBuffer => lib/libtmod_string.a
# ==========================================================
# 
# 	make lib
# 	make lib-clean
#
# Layout:
# 	tests/String.mc, tests/StringBuffer.mc 	sources
# 	build/lib/*.c 							generated C
# 	include/*.{h,mh} 						C ABI + modc import surface
# 	lib/*.o, lib/libtmod_string.a 			host link products
#
# Consumer sketch:
# 	import TString, String from "String.mh" 	# path relative to the .mc
# 	cc ... testc -Iinclude -Llib -ltmod_string
#
# Note: default `make test` does not link this archive; link explicitly.

string-lib: $(LIB_ARCHIVE)

$(LIB_ARCHIVE): $(LIB_O_FILES) $(LIB_H_FILES) $(LIB_MH_FILES) | $(LIB_DIR)
	ar rcs $@ $(LIB_O_FILES)
	ranlib $@

# Pattern: test/Foo.mc => build/lib/Foo.c + include/Foo.h + include/Foo.mh
$(LIB_BUILD_DIR)/%.c $(INCLUDE_DIR)/%.h $(INCLUDE_DIR)/%.mh: 	\
		$(TEST_DIR)/%.mc $(TARGET) | $(LIB_BUILD_DIR) $(INCLUDE_DIR)
	./$(TARGET) $< \
		-C $(LIB_BUILD_DIR)/$*.c \
		-H $(INCLUDE_DIR)/$*.h \
		-M $(INCLUDE_DIR)/$*.mh

# Pattern: build/lib/Foo.c => lib/Foo.o (needs include/Foo.h on -I path)
$(LIB_DIR)/%.o: $(LIB_BUILD_DIR)/%.c $(INCLUDE_DIR)/%.h | $(LIB_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(LIB_BUILD_DIR):
	mkdir -p $(LIB_BUILD_DIR)

$(INCLUDE_DIR):
	mkdir -p $(INCLUDE_DIR)

$(LIB_DIR):
	mkdir -p $(LIB_DIR)

string-lib-clean:
	rm -f $(LIB_ARCHIVE) $(LIB_O_FILES) $(LIB_C_FILES) $(LIB_H_FILES) $(LIB_MH_FILES)
	rm -rf $(LIB_BUILD_DIR)

# make run-lib FILE=tests/test_strings.mc
# Requires the program to import via paths that resolve to include/*.mh
# and #include "String.h" style via -Iinclude (already in CFLAGS).
run-lib: lib $(TARGET)
	@if [ -z "$(FILE)" ]; then echo "Usage: make run-lib FILE=tests/foo.mc"; exit 1; fi
	@mkdir -p $(TEST_BUILD_DIR)
	@base=$$(basename $(FILE) .mc); \
	./$(TARGET) "$(FILE)" \
		-C $(TEST_BUILD_DIR)/$$base.c \
		-H $(TEST_BUILD_DIR)/$$base.h || exit 1; \
	$(CC) $(CFLAGS) -o $(BIN_DIR)/$$base \
		$(TEST_BUILD_DIR)/$$base.c \
		-L$(LIB_DIR) -l$(LIB_NAME) || exit 1; \
	$(BIN_DIR)/$$base


# Clean generated files
clean:
# 	rm -f $(TARGET) $(C_BUILD_DIR)/*.o *.out
# 	@for file in $(TEST_FILES); do 						\
# 		rm -f "$$file" "$$file.c" "$$file.h" || true; 	\
# 	done
	rm -rf $(BUILD_DIR)
	rm -rf ${BIN_DIR}
	@echo "Clean complete."

# Very clean — also removes backup files, etc.
distclean: clean
	rm -rf $(BIN_DIR)
	rm -rf ${DIST_DIR}
# 	rm -f *~ *.bak

help:
	@echo "Available targets:"
	@echo "  version            Increment the BUILD_NUMBER and update $(SRC_DIR)/version.h"
	@echo "  all                Build the modc.$(VERSION) binary"
	@echo "  test               Run all preprocessor, compile, and run tests (test_*)"
	@echo "  test2              Run just preprocessor tests (test2_*)"
	@echo "  test3              Run negative semantic tests (test3_* - failure = pass)"
	@echo "  debug              Build with debug symbols and sanitizers"
	@echo "  clean              Remove build artifacts and generated test files"
	@echo "  distclean          Clean + remove dist directory"
	@echo "  selfhost           Regenerate .c for all src/*.mc (self-host test)"
	@echo "  bootstrap          Full bootstrap with verification (all src/*.mc)"
	@echo "  promote            Promote verified to source (after successful bootstrap)"
	@echo "  dist               Make distribution"
	@echo "  install            Install to:  $(INSTALL_DIR)"
	@echo "  uninstall          Remove from: $(INSTALL_DIR)"
	@echo "  run FILE=filename  Compile and run FILE"
	@echo "  string-lib         Build lib/lib$(LIB_NAME).a (String + StringBuffer)"
	@echo "  string-lib-clean   Remove library objects, archive, and generated surface"
	@echo "  run-lib FILE=filename  Compile and run FILE with lib"
	@echo "  cloc               Count TMod-c .mc lines (needs cloc; tools/tmodc.cloc)"
	@echo "  CC=gcc|clang|tcc   Host C compiler (default gcc). make clean when switching."
	@echo ""
	@echo "VERSION:      $(VERSION)"
	@echo "BUILD_NUMBER: $(BUILD_NUMBER)"
	@echo "TARGET:       $(TARGET)"

# Because I do this a lot; resets the terminal buffer so I can more easily find compilation errors.
reset: clean
	reset

# ======================================================
# Safe self-hosting targets
# ======================================================

# Stage 1 and 2: Generate new source into build, compile temporary compiler.
selfhost: $(TARGET)
	mkdir -p $(SH_BUILD_DIR)
	@echo "=== Stage 1: Regenerating compiler sources (all src/*.mc) ==="
	@cp -p $(SRC_DIR)/*.h $(SH_BUILD_DIR) && cp -p $(SRC_DIR)/*.c $(SH_BUILD_DIR)
	@for mc in $(SRC_MC_FILES); do 								\
		base=$$(basename $$mc .mc);								\
		c_out=$(SH_BUILD_DIR)/$$base.c;							\
		h_out=$(SH_BUILD_DIR)/$$base.h;							\
		echo "Processing $$mc -> $$c_out and $$h_out"; 			\
		./$(TARGET) $$mc -C $$c_out -H $$h_out || exit 1; 		\
	done
	@echo "=== Stage 2: Building temporary compiler ==="
	@for c in $(SH_BUILD_DIR)/*.c; do 							\
		base=$$(basename $$c .c);								\
		o_out=$(SH_BUILD_DIR)/$$base.o;							\
		$(CC) $(CFLAGS) -I $(SH_BUILD_DIR) -c $$c -o $$o_out;	\
	done
	$(CC) $(SH_BUILD_DIR)/*.o -o $(BIN_DIR)/modc.selfhost
	@echo "=== Self-hosting stage 2 complete. Temporary compiler: $(BIN_DIR)/modc.selfhost ==="

# Stage 3, 4, and 5. Full bootstrap with verification (2 stage)
bootstrap: selfhost
	mkdir -p $(BS_BUILD_DIR)
	@echo "=== Stage 3: Regenerating with new compiler ==="
	@cp -p $(SRC_DIR)/*.h $(BS_BUILD_DIR) && cp -p $(SRC_DIR)/*.c $(BS_BUILD_DIR)
	@for mc in $(SRC_MC_FILES); do 											\
		base=$$(basename $$mc .mc);											\
		c_out=$(BS_BUILD_DIR)/$$base.c;										\
		h_out=$(BS_BUILD_DIR)/$$base.h;										\
		echo "Processing $$mc -> $$c_out and $$h_out"; 						\
		./$(BIN_DIR)/modc.selfhost $$mc -C $$c_out -H $$h_out || exit 1; 	\
	done
	@echo "=== Stage 4: Building second-generation compiler ==="
	@for c in $(BS_BUILD_DIR)/*.c; do 										\
		base=$$(basename $$c .c);											\
		o_out=$(BS_BUILD_DIR)/$$base.o;										\
		$(CC) $(CFLAGS) -I $(BS_BUILD_DIR) -c $$c -o $$o_out;				\
	done
	$(CC) $(BS_BUILD_DIR)/*.o -o $(BIN_DIR)/modc.bootstrap
	@echo "=== Stage 5: Verifying identical output ==="
	@success=true;																\
	for mc in $(SRC_MC_FILES); do												\
		base=$$(basename $$mc .mc);												\
		c_regen=$(BS_BUILD_DIR)/$$base.regen.c;									\
		h_regen=$(BS_BUILD_DIR)/$$base.regen.h;									\
		./$(BIN_DIR)/modc.bootstrap $$mc -C $$c_regen -H $$h_regen || exit 1;	\
		c_selfhost=$(SH_BUILD_DIR)/$$base.c;									\
		if [ -f "$$c_selfhost" ] && [ -f "$$c_regen" ]; then					\
			if ! diff -u "$$c_selfhost" "$$c_regen" >/dev/null; then			\
				echo "=== ERROR: $$c_selfhost and $$c_regen differ ==="; 		\
				success=false;													\
			else																\
				echo "=== $$c_selfhost, $$c_regen: identical ===";				\
			fi;																	\
		else 																	\
			echo "=== ERROR: missing $$c_selfhost or $$c_regen ===";			\
			success=false;														\
		fi;																		\
		h_selfhost=$(SH_BUILD_DIR)/$$base.h;									\
		if [ -f "$$h_selfhost" ] && [ -f "$$h_regen" ]; then					\
			if ! diff -u "$$h_selfhost" "$$h_regen" >/dev/null; then			\
				echo "=== ERROR: $$h_selfhost and $$h_regen differ ==="; 		\
				success=false;													\
			else																\
				echo "=== $$h_selfhost, $$h_regen: identical ===";				\
			fi;																	\
		else 																	\
			echo "=== ERROR: missing $$h_selfhost or $$h_regen ===";			\
			success=false;														\
		fi;																		\
	done;																		\
	if $$success; then 															\
		echo "=== SUCCESS: Full bootstrap verified ===" ; 						\
		echo "=== (identical output for all sources) ===";						\
		echo "=== Run 'make promote' to update $(SRC_MC_FILES) ===" ; 			\
	else 																		\
		echo "=== ERROR: Bootstrap failed - some generated files differ ===" ; 	\
		exit 1; 																\
	fi

# Promote verified output to source (only run after successful bootstrap)
promote:
	@echo "=== Stage 6: Reverifying and Promoting files ==="	
	@success=true;														\
	for mc in $(SRC_MC_FILES); do										\
		base=$$(basename $$mc .mc);										\
		c_regen=$(BS_BUILD_DIR)/$$base.regen.c;							\
		h_regen=$(BS_BUILD_DIR)/$$base.regen.h;							\
		c_selfhost=$(SH_BUILD_DIR)/$$base.c;							\
		h_selfhost=$(SH_BUILD_DIR)/$$base.h;							\
		if ! diff -u "$$c_selfhost" "$$c_regen" >/dev/null; then		\
			echo "=== ERROR: $$c_selfhost and $$c_regen differ ==="; 	\
			success=false;												\
		fi;																\
		if ! diff -u "$$h_selfhost" "$$h_regen" >/dev/null; then		\
			echo "=== ERROR: $$h_selfhost and $$h_regen differ ==="; 	\
			success=false;												\
		fi;																\
	done;																\
	if $$success; then 													\
		for mc in $(SRC_MC_FILES); do									\
			base=$$(basename $$mc .mc);									\
			c_new=$(SH_BUILD_DIR)/$$base.c;								\
			h_new=$(SH_BUILD_DIR)/$$base.h;								\
			c_src=$(SRC_DIR)/$$base.c;									\
			h_src=$(SRC_DIR)/$$base.h;									\
			cp -fv $$c_new $$c_src;										\
			cp -fv $$h_new $$h_src;										\
		done;															\
	else																\
		echo "ERROR: Recomparison failed. Refusing to promote.";		\
		echo "ERROR: Run 'make bootstrap' first.";						\
		exit 1;															\
	fi

# Count authored .mc (src, examples, tests, hello.mc). .mc is "Windows Message
# File" in stock cloc; tools/tmodc.cloc + --force-lang remaps it. Braces are code.
CLOC ?= cloc
CLOC_LANG_DEF = tools/tmodc.cloc

cloc:
	@command -v $(CLOC) >/dev/null 2>&1 || { \
		echo "ERROR: cloc not found (install cloc, or set CLOC=...)"; \
		exit 1; \
	}
	$(CLOC) --read-lang-def=$(CLOC_LANG_DEF) --force-lang='TMod-c,mc' \
		$(SRC_DIR) $(TEST_DIR) $(EXAMPLES_DIR)

# 		--include-lang='TMod-c' \

.PHONY: all test test2 test3 clean distclean string-lib string-lib-clean tmodc cloc

# msr/gk/msr
