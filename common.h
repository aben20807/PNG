#ifndef COMMON_H
#define COMMON_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include <unistd.h>

#define TYPE_TABLE \
    Y(kI_TYPE, "int32", "I") Y(kF_TYPE, "float32", "F") \
    Y(kB_TYPE, "bool", "Z") Y(kS_TYPE, "string", "Ljava/lang/String;") \
    Y(kA_TYPE, "array", "undefined") Y(kID_TYPE, "IDENT", "undefined") \
    Y(kV_TYPE, "void", "V") Y(kN_TYPE, "ERROR", "undefined") \
    Y(kFUNC_TYPE, "func", "undefined")

#define OP_TABLE \
    X(kPOS_OP, "POS") X(kNEG_OP, "NEG") X(kNOT_OP, "NOT") \
    X(kMUL_OP, "MUL") X(kQUO_OP, "QUO") X(kREM_OP, "REM") \
    X(kADD_OP, "ADD") X(kSUB_OP, "SUB") \
    X(kLEQ_OP, "LEQ") X(kGEQ_OP, "GEQ") X(kLSS_OP, "LSS") \
    X(kGTR_OP, "GTR") X(kEQL_OP, "EQL") X(kNEQ_OP, "NEQ") \
    X(kLAND_OP, "LAND") X(kLOR_OP, "LOR") \
    X(kINC_OP, "INC") X(kDEC_OP, "DEC") X(kASSIGN_OP, "ASSIGN") \
    X(kPRINT_OP, "PRINT") X(kPRINTLN_OP, "PRINTLN")

#define JAVA_TYPE_TABLE \
    X(kI_TYPE, "I") X(kF_TYPE, "F") \
    X(kB_TYPE, "Z") X(kS_TYPE, "string") \
    X(kA_TYPE, "array") X(kID_TYPE, "IDENT") \
    X(kN_TYPE, "ERROR") 

#define X(a, b) a,
#define Y(a, b, c) a,
typedef enum { TYPE_TABLE } type_et;
typedef enum { OP_TABLE } op_et;
#undef X
#undef Y

typedef struct type_container_s {
    type_et type;         // kI_TYPE, kF_TYPE, kID_TYPE...
    type_et actual_type;  // The actual type of an identifier (type is kID_TYPE)
    type_et element_type; // The element type of an array (type is kA_TYPE)
} type_container_st;
typedef struct container_s {
    type_container_st tc;
    char *id_name;
} container_st;

#endif /* COMMON_H */
