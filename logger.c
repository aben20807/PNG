#include "logger.h"

#include <stdarg.h>  // va_start
#include <stdlib.h>

logger_st *logger_init()
{
    logger_st *logger = (logger_st *) calloc(1, sizeof(logger_st));
    logger->handlers = NULL;
    logger->handlers_num = 0;
    return logger;
}
void logger_deinit(logger_st *logger)
{
    for (int i = 0; i < logger->handlers_num; ++i) {
        free(logger->handlers[i]->filters);
        free(logger->handlers[i]);
    }
    free(logger->handlers);
    free(logger);
    logger = NULL;
}

void add_handler(logger_st *logger, handler_st *handler)
{
    int handlers_num = logger->handlers_num;
    handler_st **new_handlers = (handler_st **) realloc(
        logger->handlers, (handlers_num + 1) * sizeof(logger_st *));
    memcpy(new_handlers, logger->handlers, handlers_num * sizeof(logger_st *));
    new_handlers[handlers_num] = handler;
    logger->handlers_num++;
    logger->handlers = new_handlers;
}

handler_st *handler_init(FILE *outstream, const logger_level_et level)
{
    handler_st *handler = (handler_st *) calloc(1, sizeof(handler_st));
    handler->level = level;
    handler->stream = outstream;
    handler->filters = NULL;
    handler->filters_num = 0;
    handler->format = "%(message)s";
    return handler;
}

void set_level(handler_st *handler, const logger_level_et level)
{
    handler->level = level;
}

void set_stream(handler_st *handler, FILE *stream)
{
    handler->stream = stream;
}

void set_format(handler_st *handler, const char *format)
{
    handler->format = format;
}

void add_filter(handler_st *handler, filter_ft filter)
{
    int filters_num = handler->filters_num;
    filter_ft *new_filters = (filter_ft *) realloc(
        handler->filters, (filters_num + 1) * sizeof(filter));
    memcpy(new_filters, handler->filters, filters_num * sizeof(filter));
    new_filters[filters_num] = filter;
    handler->filters_num++;
    handler->filters = new_filters;
}


void logger_printf(logger_st *logger,
                   logger_level_et level,
                   const char *file,
                   const char *func,
                   unsigned int line,
                   const char *format,
                   ...)
{
    char *message = (char *) calloc(BUFFER_SIZE, sizeof(char));
    va_list args;
    va_start(args, format);
    int len = vsnprintf(message, BUFFER_SIZE, format, args);
    if (BUFFER_SIZE <= len) {
        printf("%d\n", len);
        message = (char *) realloc(message, (len + 1) * sizeof(char));
        va_start(args, format);
        vsnprintf(message, len + 1, format, args);
    }
    va_end(args);

    handler_st *handler;
    for (int i = 0; i < logger->handlers_num; ++i) {
        handler = logger->handlers[i];
        if (level < handler->level) {
            continue;
        }
        for (int j = 0; j < handler->filters_num; ++j) {
            if (!handler->filters[j](level, message)) {
                return;
            }
        }
        fprintf(handler->stream, FORMAT);
    }
    free(message);
    if (level == FATAL) {
        exit(1);
    }
}


bool starts_with(const char *str, const char *pre)
{
    size_t lenpre = strlen(pre), lenstr = strlen(str);
    return lenstr < lenpre ? false : memcmp(pre, str, lenpre) == 0;
}
