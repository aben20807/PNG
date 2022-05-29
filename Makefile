CC := gcc-8
CFLAGS := -Wall -O0 -ggdb
YFLAGS := -d -v
LEX_SRC := png_scanner.l
YAC_FILE := png_parser
YAC_SRC := ${YAC_FILE}.y
COMMON_HEADER := common.h
COMPILER := png_compiler
JAVABYTECODE := hw3.j
EXEC := Main


all: ${COMPILER}

${COMPILER}: lex.yy.c ${YAC_FILE}.tab.c
	${CC} ${CFLAGS} -o $@ $^

lex.yy.c: ${LEX_SRC} ${COMMON_HEADER}
	flex $<

${YAC_FILE}.tab.c: ${YAC_SRC} ${COMMON_HEADER}
	bison ${YFLAGS} $<

${JAVABYTECODE}: ${COMPILER}
ifeq (,$(wildcard ${JAVABYTECODE}))
	@echo "${JAVABYTECODE} does not exist."
endif

${EXEC}.class: ${JAVABYTECODE}
	@java -jar jasmin.jar -g ${JAVABYTECODE}

run: ${EXEC}.class
	@java ${EXEC} || java -Xverify:none ${EXEC}

judge: all
	@judge -v ${v}

clean:
	rm -f ${COMPILER} ${YAC_FILE}.tab.* ${YAC_FILE}.output lex.*
