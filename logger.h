#pragma once
#include <stdbool.h>
#include <stdio.h>
#include <string.h>

#define BUFFER_SIZE 6

typedef enum {
    NOTSET = 0,
    DEBUG = 10,
    INFO = 20,
    WARN = 30,
    ERROR = 40,
    FATAL = 50, /* will exit with non-zero status */
} logger_level_et;

typedef bool (*filter_ft)(logger_level_et level, const char *msg);

typedef struct logger_s logger_st;
typedef struct handler_s handler_st;

struct logger_s {
    handler_st **handlers;
    int handlers_num;
};

struct handler_s {
    FILE *stream;          /* log output stream. default: stdout */
    logger_level_et level; /* skip msg whose level is less than threshold.
                              default: NOTSET */
    filter_ft *filters;    /* the filters list to filter the log */
    int filters_num;       /* the number of the filters */
    const char *format;
};


logger_st *logger_init();
void logger_deinit(logger_st *logger);
void add_handler(logger_st *logger, handler_st *handler);

handler_st *handler_init(FILE *outstream, const logger_level_et level);
void set_level(handler_st *handler, const logger_level_et level);
void set_stream(handler_st *handler, FILE *stream);
void set_format(handler_st *handler, const char *format);
void add_filter(handler_st *handler, filter_ft filter);

void logger_printf(logger_st *logger,
                   logger_level_et level,
                   const char *file,
                   const char *func,
                   unsigned int line,
                   const char *format,
                   ...);

// Utilities
bool starts_with(const char *str, const char *pre);


#define LOG(logger, fmt, ...) logger_printf(logger, NOTSET, __FILE__, __FUNCTION__, __LINE__, fmt, ##__VA_ARGS__)
#define LOG_DEBUG(logger, fmt, ...) \
    logger_printf(logger, DEBUG, __FILE__, __FUNCTION__, __LINE__, fmt, ##__VA_ARGS__)
#define LOG_INFO(logger, fmt, ...) \
    logger_printf(logger, INFO, __FILE__, __FUNCTION__, __LINE__, fmt, ##__VA_ARGS__)
#define LOG_WARN(logger, fmt, ...) \
    logger_printf(logger, WARN, __FILE__, __FUNCTION__, __LINE__, fmt, ##__VA_ARGS__)
#define LOG_ERROR(logger, fmt, ...) \
    logger_printf(logger, ERROR, __FILE__, __FUNCTION__, __LINE__, fmt, ##__VA_ARGS__)
#define LOG_FATAL(logger, fmt, ...) \
    logger_printf(logger, FATAL, __FILE__, __FUNCTION__, __LINE__, fmt, ##__VA_ARGS__)
