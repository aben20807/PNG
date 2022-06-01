CC ?= gcc-8
CFLAGS ?= -Wall -O0 -ggdb -std=gnu99 -D_GNU_SOURCE
YFLAGS ?= -d -v

LEX_SRC ?= png_scanner.l
YAC_FILE ?= png_parser
YAC_SRC ?= $(YAC_FILE).y
COMMON_HEADER ?= common.h

BUILD_DIR ?= build
BIN_DIR ?= bin

COMPILER ?= $(BIN_DIR)/png_compiler
JAVABYTECODE ?= hw3.j
EXEC ?= Main

v ?= 0

# LIB := 3rdparty/threaded-logger
OBJS := logger.o
deps := $(OBJS:%.o=%.o.d)
OBJS := $(addprefix $(BUILD_DIR)/,$(OBJS))
deps := $(addprefix $(BUILD_DIR)/,$(deps))


.PHONY: check clean

all: $(COMPILER)

$(BUILD_DIR)/%.o: %.c
	$(CC) $(CFLAGS) -c -o $@ -MMD -MF $@.d $<

$(COMPILER): lex.yy.c $(YAC_FILE).tab.c $(OBJS) | $(BIN_DIR)
	$(CC) $(CFLAGS) -o $@ $^

lex.yy.c: $(LEX_SRC) $(COMMON_HEADER)
	flex $<

$(YAC_FILE).tab.c: $(YAC_SRC) $(COMMON_HEADER)
	bison $(YFLAGS) $<

$(OBJS): | $(BUILD_DIR) $(BUILD_DIR)/$(LIB)

$(BUILD_DIR):
	mkdir -p $@

$(BIN_DIR):
	mkdir -p $@

$(JAVABYTECODE): $(COMPILER)
ifeq (,$(wildcard $(JAVABYTECODE)))
	@echo "$(JAVABYTECODE) does not exist."
endif

$(EXEC).class: $(JAVABYTECODE)
	@java -jar 3rdparty/jasmin.jar -g $(JAVABYTECODE)

run: $(EXEC).class
	@java $(EXEC) || java -Xverify:none $(EXEC)

check: all
	@cd tests/ && judge -v $(v) && rm -f $(EXEC).class *.j && cd ../

clean:
	rm -rf $(BUILD_DIR)
	rm -rf $(BIN_DIR)
	rm -f $(COMPILER) $(YAC_FILE).tab.* $(YAC_FILE).output lex.* $(EXEC).class *.j
