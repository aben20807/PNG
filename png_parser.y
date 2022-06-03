/*
    filename: compiler_hw3.y
    codeing style: https://codingart.readthedocs.io/en/latest/c/Naming.html#
*/


/*	Definition section */
%{
    #include "common.h" //Extern variables that communicate with lex
    #include "miniclog.h"
    // #define YYDEBUG 1
    // int yydebug = 1;

    extern int yylineno;
    extern int yylex();
    extern FILE *yyin;

    #define P_LOG(...) \
        LOG_DEBUG(parser_logger, __VA_ARGS__)
    #define P_LOG_ERROR(...) \
        LOG_ERROR(parser_logger, __VA_ARGS__)

    int yylex_destroy ();
    void yyerror (char const *s)
    {
        printf("error:%d: %s\n", yylineno, s);
    }

    #define X(a, b) b,
    #define Y(a, b, c) b,
    const char *get_op_name(op_et op) {
        static const char *s_ops[] = { OP_TABLE };
        return s_ops[op];
    }
    const char *get_type_name(type_et type) {
        static const char *s_types[] = { TYPE_TABLE };
        return s_types[type];
    }
    #undef X
    #undef Y
    #define Y(a, b, c) c,
    const char *get_java_type(type_et type) {
        static const char *s_java_type[] = { TYPE_TABLE };
        return s_java_type[type];
    }
    #undef Y

    #define CODEGEN(...) \
        do { \
            for (int i = 0; i < g_indent_cnt; i++) { \
                fprintf(fout, "\t"); \
            } \
            fprintf(fout, __VA_ARGS__); \
        } while (0)
    
    #define CODEGEN_NO_INDENT(...) \
        do { \
            fprintf(fout, __VA_ARGS__); \
        } while (0)

    /* Symbol table structure */
    typedef struct entry_s entry_st;
    struct entry_s {
        int index;
        char *name;
        type_et type;
        int address;
        int lineno;
        type_et element_type;
        char *func_signature;
        entry_st *next;
    };

    typedef struct table_s table_st;
    struct table_s {
        table_st *prev;
        int scope_level;
        int variable_count;
        entry_st *entry_head;
        entry_st *entry_tail;
    };

    typedef struct case_map_s {
        int index;
        int label;
    } case_map_st;

    /* Symbol table function - you can add new function if needed. */
    static table_st *create_scope_symbol_table(const int scope_level, table_st *prev);
    static int insert_symbol(table_st *table, char *name, const type_container_st tc);
    static entry_st *lookup_symbol(const table_st *table, const char *name);
    static void dump_symbol(table_st *table);
    static entry_st *create_entry(char *name, const type_container_st tc);
    static void new_scope();
    static void dump_scope();

    /* Symbol table global variables */
    table_st *g_root_table = NULL;
    table_st *g_cur_scope_table = NULL;
    int g_scope_level = 0;
    int g_variable_unique_address = 0;
    bool g_has_gen_return_stmt = false;
    bool g_in_parameter_list = false;
    char *g_cur_func_signature = NULL;
    const int kSIGNATURE_LEN = 20;

    /* Custom functions */
    static type_et check_type_equality_for_op(const op_et op, const container_st a, const container_st b);
    static type_et assert_type_for_op(const op_et op, const type_et truth, const container_st a, const container_st b);
    static type_et assert_type_for_condition(const type_et truth, const container_st ctr);
    static entry_st *check_declaration(const char *name);
    static void check_redeclaration(const char *name);
    static void check_func_redeclaration(const char *name);
    static const char *get_mnemonic(const type_et type, const op_et op);
    /* codegen */
    static void gen_cmp_expression(const op_et op, const type_et exptype);
    static void gen_ident_load(const container_st ctr);
    static void gen_array_load(const container_st ctr);
    static void gen_ident_store(const container_st ctr);
    static void gen_decl_statement(const int addr, const type_container_st tc, const bool has_init_val);
    static void gen_print_statement(const op_et op, const type_et exptype);
    static void gen_return_statement(const type_et exptype);

    /* Other global variables */
    logger_st* parser_logger = NULL;
    FILE *fout = NULL;
    bool g_has_error = false;
    int g_indent_cnt = 0;
    int g_cmp_op_unique_label = 0;
    int g_case_unique_label = 0;
    int g_switch_unique_label = 0;
    case_map_st g_case_map[100] = {};
    int g_case_num = 0;
    int g_if_false_labels[100] = {};
    int g_if_exit_labels[100] = {};
    int g_exit_label_first = 0;
    int g_for_begin_labels[100] = {};
    int g_for_exit_labels[100] = {};
    int g_for_init_labels[100] = {};
    int g_for_post_labels[100] = {};
    int g_for_body_labels[100] = {};
%}

%define parse.error verbose

/* Use variable or self-defined structure to represent
 * nonterminal and token type
 */
%union {
    int i;
    float f;
    char *s;
    bool b;
    container_st ctr;
    op_et op;
}

/* Token without return */
%token VAR PACKAGE FUNC RETURN
%token INT FLOAT BOOL STRING
%token NEWLINE
%token PRINT PRINTLN
%token IF ELSE FOR
%token SWITCH CASE DEFAULT
%token ADD_ASSIGN SUB_ASSIGN MUL_ASSIGN QUO_ASSIGN REM_ASSIGN
%token INC DEC
%token LEQ GEQ EQL NEQ
%token LAND LOR

/* Token with return, which need to sepcify type */
%token <ctr> INT_LIT
%token <ctr> FLOAT_LIT
%token <ctr> STRING_LIT
%token <ctr> TRUE FALSE
%token <ctr> IDENT

/* Nonterminal with return, which need to sepcify type */
%type <ctr> Type TypeName ArrayType ReturnType FuncOpen AddressableExpr
%type <ctr> Expression OrExpr AndExpr CmpExpr AddExpr MulExpr FuncCallExpr
%type <ctr> UnaryExpr PrimaryExpr Operand IndexExpr ConversionExpr Literal
%type <op> CmpOp AddSubOp MulDivRemOp UnaryOp AssignOp IncDecOp PrintOp

/* Yacc will start at this nonterminal */
%start Program

/* Grammar section */
%%

Program
    : GlobalStatementList
;

Type
    : TypeName { $$ = $1; }
    | ArrayType { $$ = $1; }
;

TypeName
    : INT  { $$.tc.type = kI_TYPE; }
    | FLOAT  { $$.tc.type = kF_TYPE;}
    | STRING  { $$.tc.type = kS_TYPE; }
    | BOOL  { $$.tc.type = kB_TYPE; }
;

ArrayType
    : '[' Expression ']' Type {
        $$.tc.type = kA_TYPE;
        $$.tc.element_type = $4.tc.type;
    }
;

Expression
    : OrExpr { $$ = $1; }
    | FuncCallExpr
    
;

ArgumentList
    : Expression
    | ArgumentList ',' Expression
    | { /* no argument */ }
;

FuncCallExpr
    : IDENT '(' ArgumentList ')' {
        entry_st *func = check_declaration($1.id_name);
        free($1.id_name);
        CODEGEN("invokestatic Main/");
        CODEGEN_NO_INDENT("%s%s\n", func->name, func->func_signature);
    }
;

OrExpr
    : AndExpr { $$ = $1; }
    | OrExpr LOR AndExpr {
        assert_type_for_op(kLOR_OP, kB_TYPE, $1, $3);
        CODEGEN("ior\n");
        P_LOG("%s\n", get_op_name(kLOR_OP));
    }
;

AndExpr
    : CmpExpr { $$ = $1; }
    | AndExpr LAND CmpExpr {
        assert_type_for_op(kLAND_OP, kB_TYPE, $1, $3);
        CODEGEN("iand\n");
        P_LOG("%s\n", get_op_name(kLAND_OP));
    }
;

CmpExpr
    : AddExpr { $$ = $1; }
    | CmpExpr CmpOp AddExpr {
        type_et t = check_type_equality_for_op($<op>2, $1, $3);
        $$.tc.type = kB_TYPE;
        gen_cmp_expression($<op>2, t);
        P_LOG("%s\n", get_op_name($<op>2));
    }
;

CmpOp
    : EQL { $<op>$ = kEQL_OP; }
    | NEQ { $<op>$ = kNEQ_OP; }
    | '<' { $<op>$ = kLSS_OP; }
    | LEQ { $<op>$ = kLEQ_OP; }
    | '>' { $<op>$ = kGTR_OP; }
    | GEQ { $<op>$ = kGEQ_OP; }
;

AddExpr
    : MulExpr { $$ = $1; }
    | AddExpr AddSubOp MulExpr {
        type_et t = check_type_equality_for_op($<op>2, $1, $3);
        $$.tc.type = t;
        CODEGEN("%s\n", get_mnemonic(t, $<op>2));
        P_LOG("%s\n", get_op_name($<op>2));
    }

AddSubOp
    : '+' { $<op>$ = kADD_OP; }
    | '-' { $<op>$ = kSUB_OP; }
;

MulExpr
    : UnaryExpr { $$ = $1; }
    | MulExpr MulDivRemOp UnaryExpr {
        type_et t;
        if ($<op>2 == kREM_OP) {
            t = assert_type_for_op(kREM_OP, kI_TYPE, $1, $3);
        } else {
            t = check_type_equality_for_op($<op>2, $1, $3);
        }
        $$.tc.type = t;
        CODEGEN("%s\n", get_mnemonic(t, $<op>2));
        P_LOG("%s\n", get_op_name($<op>2));
    }
;

MulDivRemOp
    : '*' { $<op>$ = kMUL_OP; }
    | '/' { $<op>$ = kQUO_OP; }
    | '%' { $<op>$ = kREM_OP; }
;

UnaryExpr
    : PrimaryExpr { $$ = $1; }
    | UnaryOp UnaryExpr {
        $$ = $2;
        CODEGEN("%s\n", get_mnemonic($2.tc.type, $<op>1));
        P_LOG("%s\n", get_op_name($<op>1));
    }
;

UnaryOp
    : '+' { $<op>$ = kPOS_OP; }
    | '-' { $<op>$ = kNEG_OP; }
    | '!' { $<op>$ = kNOT_OP;
        CODEGEN("iconst_1\n");
    }
;

PrimaryExpr
    : Operand { $$ = $1; }
    | IndexExpr { $$ = $1; }
    | ConversionExpr { $$ = $1; }
;

Operand
    : Literal { $$ = $1; }
    | IDENT {
        entry_st *ident = check_declaration(yylval.ctr.id_name);
        free(yylval.ctr.id_name);
        if (ident != NULL) {
            $$.id_name = ident->name;
            $$.tc.type = kID_TYPE;
            $$.tc.actual_type = ident->type;
            if ($$.tc.actual_type == kA_TYPE) {
                $$.tc.element_type = ident->element_type;
            }
            // gen_ident_expression();
         P_LOG("IDENT (name=%s, address=%d)\n", ident->name, ident->address);
        } else {
            $$.tc.type = kID_TYPE;
            $$.tc.actual_type = kN_TYPE;
        }
        gen_ident_load($$);
    }
    | '(' Expression ')' { $$ = $2; }
;

Literal
    : INT_LIT {
        P_LOG("INT_LIT %d\n", $<i>$);
        CODEGEN("ldc %d\n", $<i>$);
        $$.tc.type = kI_TYPE;
    }
    | FLOAT_LIT {
        P_LOG("FLOAT_LIT %f\n", $<f>$);
        CODEGEN("ldc %f\n", $<f>$);
        $$.tc.type = kF_TYPE;
    }
    | TRUE {
        P_LOG("TRUE %d\n", $<b>$);
        CODEGEN("iconst_1\n");
        $$.tc.type = kB_TYPE;
    }
    | FALSE {
        P_LOG("FALSE %d\n", $<b>$);
        CODEGEN("iconst_0\n");
        $$.tc.type = kB_TYPE;
    }
    | '"' STRING_LIT '"' {
        P_LOG("STRING_LIT %s\n", $<s>2);
        CODEGEN("ldc \"%s\"\n", $<s>2);
        free($<s>2);
        $$.tc.type = kS_TYPE;
    }
;

IndexExpr
    : AddressableExpr '[' Expression ']' {
        $$.tc.type = $1.tc.type;
        $$.tc.actual_type = $1.tc.element_type;
        gen_ident_load($$);
    }
;

ConversionExpr
    : Type '(' Expression ')' {
        $$.tc.type = $1.tc.type;
        type_et from_type = $3.tc.type == kID_TYPE ? $3.tc.actual_type : $3.tc.type;
        type_et to_type = $1.tc.type;
        if (from_type == kI_TYPE && to_type == kF_TYPE) {
            CODEGEN("i2f\n");
            P_LOG("i2f\n");
        } else if (from_type == kF_TYPE && to_type == kI_TYPE) {
            CODEGEN("f2i\n");
            P_LOG("f2i\n");
        }
    }
;

PackageStmt
    : PACKAGE IDENT {
        free(yylval.ctr.id_name);
    }
;

ParameterList
    : IDENT Type {
        check_redeclaration($1.id_name);
        P_LOG("param %s, type: %s\n", $1.id_name, get_java_type($2.tc.type));
        strcat(g_cur_func_signature, get_java_type($2.tc.type));
        insert_symbol(g_cur_scope_table, $1.id_name, $2.tc);
        CODEGEN_NO_INDENT("%s", get_java_type($2.tc.type));
    }
    | ParameterList ',' IDENT Type {
        check_redeclaration($3.id_name);
        P_LOG("param %s, type: %s\n", $3.id_name, get_java_type($4.tc.type));
        strcat(g_cur_func_signature, get_java_type($4.tc.type));
        insert_symbol(g_cur_scope_table, $3.id_name, $4.tc);
        CODEGEN_NO_INDENT("%s", get_java_type($4.tc.type));
    }
    | { /* no parameter */ }
;

FunctionDeclStmt
    : FuncOpen '(' {
        // use concat to store the whole signature
        g_cur_func_signature = calloc(kSIGNATURE_LEN, sizeof(char));
        strcat(g_cur_func_signature, "(");
        g_in_parameter_list = true;
        g_has_gen_return_stmt = false;
        new_scope();
    } ParameterList ')' ReturnType {
        g_in_parameter_list = false;
        strcat(g_cur_func_signature, ")");
        strcat(g_cur_func_signature, get_java_type($6.tc.type));
        P_LOG("func_signature: %s\n", g_cur_func_signature);

        char* func_name = $1.id_name;
        type_container_st func_tc = {kFUNC_TYPE};
        yylineno++;
        insert_symbol(g_root_table, func_name, func_tc);
        yylineno--;
        entry_st *func = lookup_symbol(g_root_table, func_name);
        func->func_signature = g_cur_func_signature;

        if (strcmp(func->name, "main") == 0) { // parameter of main is special
            CODEGEN_NO_INDENT("[Ljava/lang/String;");
        }
        CODEGEN_NO_INDENT(")");
        CODEGEN_NO_INDENT("%s\n", get_java_type($6.tc.type));
        CODEGEN_NO_INDENT(".limit stack 20\n");
        CODEGEN_NO_INDENT(".limit locals 20\n");
    } FuncBlock {
        // generate return if there is no return statement yet
        if (!g_has_gen_return_stmt) {
            CODEGEN("return\n");
        }
        CODEGEN_NO_INDENT(".end method\n");
    }
;

FuncOpen
    : FUNC IDENT {
        $$ = $2;
        char* func_name = yylval.ctr.id_name;
        check_func_redeclaration(func_name);
        P_LOG("func %s\n", func_name);
        CODEGEN_NO_INDENT("\n\n.method public static %s(", func_name);
    }
;

ReturnType
    : Type { $$ = $<ctr>1; }
    | { // void return
        $<ctr>$.tc.type = kV_TYPE; 
    }
;

GlobalStatement
    : PackageStmt EOL
    | FunctionDeclStmt
    | EOL
;

GlobalStatementList 
    : GlobalStatementList GlobalStatement
    | GlobalStatement
;

Statement
    : DeclarationStmt EOL
    | SimpleStmt EOL
    | Block
    | IfStmt
    | ForStmt
    | SwitchStmt
    | CaseStmt
    | PrintStmt EOL
    | ReturnStmt EOL
    | EOL
;

EOL
    : NEWLINE
;

SimpleStmt
    : AssignmentStmt
    | ExpressionStmt
    | IncDecStmt
;

ReturnStmt
    : RETURN Expression {
        type_et type = $2.tc.type;
        if (type == kID_TYPE) {
            type = $2.tc.actual_type;
        }
        gen_return_statement(type);
        g_has_gen_return_stmt = true;
    }
    | RETURN {
        CODEGEN("return\n");
        g_has_gen_return_stmt = true;
    }
;

DeclarationStmt
    : VAR IDENT Type {
        check_redeclaration($2.id_name);
        int addr = insert_symbol(g_cur_scope_table, $2.id_name, $3.tc);
        gen_decl_statement(addr, $3.tc, false);
    }
    | VAR IDENT Type '=' Expression {
        check_redeclaration($2.id_name);
        int addr = insert_symbol(g_cur_scope_table, $2.id_name, $3.tc);
        gen_decl_statement(addr, $3.tc, true);
    }
    | VAR IDENT '=' Expression {
        // auto type inference
        check_redeclaration($2.id_name);
        int addr = insert_symbol(g_cur_scope_table, $2.id_name, $4.tc);
        gen_decl_statement(addr, $4.tc, true);
    }
;

AssignmentStmt
    : AddressableExpr AssignOp Expression {
        type_et t = check_type_equality_for_op($<op>2, $1, $3);
        if ($<op>2 != kASSIGN_OP) {
            entry_st *ident = check_declaration($1.id_name);
            if (ident->type == kA_TYPE) {
                CODEGEN("swap\n"); // swap index and Expression
                CODEGEN("dup_x1\n"); // to copy the index
            }
            gen_ident_load($1);
            CODEGEN("swap\n");
            CODEGEN("%s\n", get_mnemonic(t, $<op>2));
        }
        gen_ident_store($1);
        P_LOG("%s\n", get_op_name($<op>2));
    }
;

AddressableExpr
    : IDENT {
        entry_st *ident = check_declaration(yylval.ctr.id_name);
        free(yylval.ctr.id_name);
        if (ident != NULL) {
            $$.id_name = ident->name;
            $$.tc.type = kID_TYPE;
            $$.tc.actual_type = ident->type;
            if ($$.tc.actual_type == kA_TYPE) {
                $$.tc.element_type = ident->element_type;
            }
            P_LOG("IDENT (name=%s, address=%d)\n", ident->name, ident->address);
        } else {
            $$.tc.type = kID_TYPE;
            $$.tc.actual_type = kN_TYPE;
        }
        // we do not gen load here because assignment (=) does not need
        // while accumlation (+=, *=, ++, --) and index ([]) need
        // Ref: AssignmentStmt, IndexExpr
    }
    | AddressableExpr '[' Expression ']' {
        $$.id_name = $1.id_name;
        $$.tc.type = $1.tc.type;
        $$.tc.actual_type = $1.tc.element_type;
        gen_array_load($$);
    }

AssignOp
    : '=' { $<op>$ = kASSIGN_OP; }
    | ADD_ASSIGN { $<op>$ = kADD_OP; }
    | SUB_ASSIGN { $<op>$ = kSUB_OP; }
    | MUL_ASSIGN { $<op>$ = kMUL_OP; }
    | QUO_ASSIGN { $<op>$ = kQUO_OP; }
    | REM_ASSIGN { $<op>$ = kREM_OP; }
;

ExpressionStmt
    : Expression
;

IncDecStmt
    : AddressableExpr IncDecOp {
        entry_st *ident = check_declaration($1.id_name);
        type_et gen_type = ident->type;
        if (ident->type == kA_TYPE) {
            CODEGEN("dup\n"); // to copy the index
            gen_type = ident->element_type;
        }
        gen_ident_load($1);
        
        if (gen_type == kI_TYPE) {
            CODEGEN("ldc 1\n");
        } else if (gen_type == kF_TYPE) {
            CODEGEN("ldc 1.0\n");
        }
        if ($<op>2 == kINC_OP) {
            CODEGEN("%s\n", get_mnemonic(gen_type, kADD_OP));
        } else {
            CODEGEN("%s\n", get_mnemonic(gen_type, kSUB_OP));
        }
        gen_ident_store($1);
        P_LOG("%s\n", get_op_name($<op>2));
    }
;

IncDecOp
    : INC { $<op>$ = kINC_OP; }
    | DEC { $<op>$ = kDEC_OP; }
;

Block
    : '{' {
        new_scope();
    } 
    StatementList
    '}' {
        dump_scope();
    }
;

FuncBlock
    : '{' 
        StatementList
    '}' {
        dump_scope();
    }
;

StatementList 
    : StatementList Statement
    | Statement
;

IfStmt
    : IF Condition {
        CODEGEN("ifeq L_if_false_%d_%d\n", g_scope_level, g_if_false_labels[g_scope_level]);
    } Block Then
;

Then
    : ELSE { /* if else */
        CODEGEN("goto L_if_exit_%d_%d\n", g_scope_level, g_if_exit_labels[g_scope_level]++);
        g_indent_cnt--;
        CODEGEN("L_if_false_%d_%d :\n", g_scope_level, g_if_false_labels[g_scope_level]);
        g_indent_cnt++;
        g_if_false_labels[g_scope_level]++;
    } Block {
        g_exit_label_first = g_if_exit_labels[g_scope_level] - 1;
        g_indent_cnt--;
        CODEGEN("L_if_exit_%d_%d :\n", g_scope_level, g_exit_label_first--);
        g_indent_cnt++;
    }
    | ELSE { /* if else if */
        CODEGEN("goto L_if_exit_%d_%d\n", g_scope_level, g_if_exit_labels[g_scope_level]++);
        g_indent_cnt--;
        CODEGEN("L_if_false_%d_%d :\n", g_scope_level, g_if_false_labels[g_scope_level]);
        g_indent_cnt++;
        g_if_false_labels[g_scope_level]++;
    } IfStmt {
        g_indent_cnt--;
        CODEGEN("L_if_exit_%d_%d :\n", g_scope_level, g_exit_label_first--);
        g_indent_cnt++;
    }
    | { /* if */
        CODEGEN("goto L_if_exit_%d_%d\n", g_scope_level, g_if_exit_labels[g_scope_level]);
        g_indent_cnt--;
        CODEGEN("L_if_false_%d_%d :\n", g_scope_level, g_if_false_labels[g_scope_level]);
        g_if_false_labels[g_scope_level]++;
        g_exit_label_first = g_if_exit_labels[g_scope_level];
        CODEGEN("L_if_exit_%d_%d :\n", g_scope_level, g_exit_label_first--);
        g_indent_cnt++;
        g_if_exit_labels[g_scope_level]++;
    }
;

ForStmt
    : FOR {
        CODEGEN("L_for_begin_%d_%d :\n", g_scope_level, g_for_begin_labels[g_scope_level]);
    } ForBody
;

ForBody
    : Condition {
        CODEGEN("ifeq L_for_exit_%d_%d\n", g_scope_level, g_for_exit_labels[g_scope_level]);
    } Block {
        CODEGEN("goto L_for_begin_%d_%d\n", g_scope_level, g_for_begin_labels[g_scope_level]);
        g_for_begin_labels[g_scope_level]++;
        g_indent_cnt--;
        CODEGEN("L_for_exit_%d_%d :\n", g_scope_level, g_for_exit_labels[g_scope_level]);
        g_indent_cnt++;
        g_for_exit_labels[g_scope_level]++;
    }
    | ForClause {
        CODEGEN("ifeq L_for_exit_%d_%d\n", g_scope_level, g_for_exit_labels[g_scope_level]);
    } Block {
        CODEGEN("goto L_for_post_%d_%d\n", g_scope_level, g_for_post_labels[g_scope_level]++);
        g_indent_cnt--;
        CODEGEN("L_for_exit_%d_%d :\n", g_scope_level, g_for_exit_labels[g_scope_level]++);
        g_indent_cnt++;
    }
;

Condition
    : Expression {
        // yylineno++; // Because we have not parsed the newline yet
        assert_type_for_condition(kB_TYPE, $1);
        // yylineno--;
    }
;

ForClause
    : InitStmt ';' {
        g_for_begin_labels[g_scope_level]++;
        g_indent_cnt--;
        CODEGEN("L_for_init_%d_%d :\n", g_scope_level, g_for_init_labels[g_scope_level]);
        g_indent_cnt++;
    } Condition ';' {
        CODEGEN("goto L_for_body_%d_%d\n", g_scope_level, g_for_body_labels[g_scope_level]);
        g_indent_cnt--;
        CODEGEN("L_for_post_%d_%d :\n", g_scope_level, g_for_post_labels[g_scope_level]);
        g_indent_cnt++;
    } PostStmt {
        CODEGEN("goto L_for_init_%d_%d\n", g_scope_level, g_for_init_labels[g_scope_level]++);
        g_for_init_labels[g_scope_level]++;
        g_indent_cnt--;
        CODEGEN("L_for_body_%d_%d :\n", g_scope_level, g_for_body_labels[g_scope_level]++);
        g_indent_cnt++;
    }
;

InitStmt
    : SimpleStmt
;

PostStmt
    : SimpleStmt
;

PrintStmt
    : PrintOp '(' Expression ')' {
        type_et type = $3.tc.type;
        if (type == kID_TYPE) {
            type = $3.tc.actual_type;
        }
        gen_print_statement($<op>1, type);
        P_LOG("%s %s\n", get_op_name($<op>1), get_type_name(type));
    }
;

SwitchStmt
    : SWITCH Expression {
        g_case_num = 0; // reset
        CODEGEN("goto L_switch_begin_%d\n", g_switch_unique_label);
    } Block {
        CODEGEN_NO_INDENT("L_switch_begin_%d:\n", g_switch_unique_label);
        CODEGEN_NO_INDENT("lookupswitch\n");
        for (int i = 0; i < g_case_num-1; i++) {
            CODEGEN("%d: L_case_%d\n", g_case_map[i].index, g_case_map[i].label);
        }
        CODEGEN("default: L_case_%d\n", g_case_map[g_case_num-1].label);
        CODEGEN_NO_INDENT("L_switch_end_%d:\n", g_switch_unique_label++);
    }
;

CaseStmt
    : CASE INT_LIT {
        P_LOG("case %d\n", $<i>2);
    } ':' {
        CODEGEN_NO_INDENT("L_case_%d:\n", g_case_unique_label);
    } Block {
        CODEGEN("goto L_switch_end_%d\n", g_switch_unique_label);
        g_case_map[g_case_num++] = (case_map_st){$<i>2, g_case_unique_label++};
    }
    | DEFAULT ':' {
        CODEGEN_NO_INDENT("L_case_%d:\n", g_case_unique_label);
    } Block {
        CODEGEN("goto L_switch_end_%d\n", g_switch_unique_label);
        g_case_map[g_case_num++] = (case_map_st){0, g_case_unique_label++};
    }
;

PrintOp
    : PRINT { $<op>$ = kPRINT_OP; }
    | PRINTLN { $<op>$ = kPRINTLN_OP; }
;

%%

/* C code section */
int main(int argc, char *argv[])
{
    parser_logger = logger_init();
    handler_st* h = handler_init(stdout, MINICLOG_NOTSET);
    add_handler(parser_logger, h);

    if (argc == 2) {
        yyin = fopen(argv[1], "r");
    } else {
        yyin = stdin;
    }
    if (!yyin) {
        LOG_FATAL(parser_logger, "file `%s` doesn't exists or cannot be opened\n", argv[1]);
    }

    /* Codegen output init */
    char *bytecode_filename = "hw3.j";
    fout = fopen(bytecode_filename, "w");
    CODEGEN(".source hw3.j\n");
    CODEGEN(".class public Main\n");
    CODEGEN(".super java/lang/Object\n");
    g_indent_cnt++;
    
    /* Symbol table init */
    g_root_table = create_scope_symbol_table(0, NULL);
    g_cur_scope_table = g_root_table;

    yylineno = 0;
    yyparse();
    dump_scope(); // global scope

 P_LOG("Total lines: %d\n", yylineno);

    /* Codegen end */
    fclose(fout);
    fclose(yyin);

    if (g_has_error) {
        remove(bytecode_filename);
    }
    yylex_destroy();
    logger_deinit(parser_logger);
    return 0;
}

static table_st *create_scope_symbol_table(const int scope_level, table_st *prev)
{
    table_st *ret = malloc(sizeof(table_st));
    ret->prev = prev;
    ret->scope_level = scope_level;
    ret->variable_count = 0;
    ret->entry_head = NULL;
    ret->entry_tail = ret->entry_head;
    return ret;
}

static entry_st *create_entry(char *name, const type_container_st tc)
{
    entry_st *ret = malloc(sizeof(entry_st));
    ret->index = -1;
    ret->name = name;//strdup(name);
    /* free(name); */
    ret->type = tc.type;
    if (ret->type == kA_TYPE) {
        ret->element_type = tc.element_type;
    }
    if (ret->type == kFUNC_TYPE) {
        ret->address = -1;
    } else {
        ret->address = g_variable_unique_address++;
    }
    ret->lineno = yylineno;
    ret->func_signature = NULL;
    ret->next = NULL;
    return ret;
}

static int insert_symbol(table_st *table, char *name, const type_container_st tc)
{
    entry_st *entry = create_entry(name, tc);
    entry->index = table->variable_count++;
    if (table->entry_head == NULL) {
        table->entry_head = entry;
        table->entry_tail = table->entry_head;
    } else {
        table->entry_tail->next = entry;
        table->entry_tail = table->entry_tail->next;
    }
    return entry->address;
}

static entry_st *lookup_symbol(const table_st *table, const char *name)
{
    entry_st *cur = table->entry_head;
    while (cur != NULL) {
        if (strcmp(name, cur->name) == 0) {
            return cur;
        }
        cur = cur->next;
    }
    return NULL;
}

static void dump_symbol(table_st *table) {
    P_LOG("\nScope level: %d\n", table->scope_level);
    P_LOG("%-10s%-10s%-10s%-10s%-10s%-10s%-10s\n",
           "Index", "Name", "Type", "Addr", "Lineno", "Ele_type", "Func_sig");
    entry_st *cur = table->entry_head;
    while (cur != NULL) {
        P_LOG("%-10d%-10s%-10s%-10d%-10d",
            cur->index, cur->name,
            get_type_name(cur->type),
            cur->address, cur->lineno);
        if (cur->type == kA_TYPE) {
            P_LOG("%-10s", get_type_name(cur->element_type));
        } else {
            P_LOG("%-10s", "-");
        }
        if (cur->type == kFUNC_TYPE) {
            P_LOG("%-10s\n", cur->func_signature);
        } else {
            P_LOG("%-10s\n", "-");
        }
        entry_st *tmp = cur;
        cur = cur->next;
        free(tmp->name);
        free(tmp->func_signature);
        free(tmp);
    }
    P_LOG("\n");
    table_st *tmp = g_cur_scope_table;
    g_cur_scope_table = tmp->prev;
    free(tmp);
}

static void new_scope()
{
    table_st *tmp = create_scope_symbol_table(++g_scope_level, g_cur_scope_table);
    g_cur_scope_table = tmp;
}

static void dump_scope()
{
    dump_symbol(g_cur_scope_table);
    g_scope_level--;
}

static type_et check_type_equality_for_op(const op_et op, const container_st a, const container_st b)
{
    type_et a_type = a.tc.type;
    type_et b_type = b.tc.type;
    if (a_type == kID_TYPE) {
        a_type = a.tc.actual_type;
    }
    if (b_type == kID_TYPE) {
        b_type = b.tc.actual_type;
    }
    if (a_type != b_type) {
        char errmsg[200] = {};
        snprintf(errmsg, sizeof(errmsg),
            "invalid operation: %s (mismatched types %s and %s)",
            get_op_name(op), get_type_name(a_type), get_type_name(b_type));
        yyerror(errmsg);
        g_has_error = true;
        return kN_TYPE;
    }
    return a_type;
}

static type_et assert_type_for_op(const op_et op, const type_et truth, const container_st a, const container_st b)
{
    type_et a_type = a.tc.type;
    type_et b_type = b.tc.type;
    if (a_type == kID_TYPE) {
        a_type = a.tc.actual_type;
    }
    if (b_type == kID_TYPE) {
        b_type = b.tc.actual_type;
    }
    char errmsg[200] = {};
    if (truth != a_type) {
        snprintf(errmsg, sizeof(errmsg),
            "invalid operation: (operator %s not defined on %s)",
            get_op_name(op), get_type_name(a_type));
        yyerror(errmsg);
        g_has_error = true;
        return kN_TYPE;
    }
    if (truth != b_type) {
        snprintf(errmsg, sizeof(errmsg),
            "invalid operation: (operator %s not defined on %s)",
            get_op_name(op), get_type_name(b_type));
        yyerror(errmsg);
        g_has_error = true;
        return kN_TYPE;
    }
    return truth;
}

static type_et assert_type_for_condition(const type_et truth, const container_st ctr)
{
    type_et ctr_type = ctr.tc.type;
    if (ctr_type == kID_TYPE) {
        ctr_type = ctr.tc.actual_type;
    }
    if (ctr_type != truth) {
        char errmsg[200] = {};
        snprintf(errmsg, sizeof(errmsg),
            "non-bool (type %s) used as for condition",
            get_type_name(ctr_type));
        yyerror(errmsg);
        g_has_error = true;
        return kN_TYPE;
    }
    return truth;
}

static entry_st *check_declaration(const char *name)
{
    table_st *cur_table = g_cur_scope_table;
    while (cur_table != NULL) {
        entry_st *target = lookup_symbol(cur_table, name);
        if (target != NULL) {
            return target;
        }
        cur_table = cur_table->prev;
    }
    char errmsg[200] = {};
    snprintf(errmsg, sizeof(errmsg),
        "undefined: %s", name);
    yyerror(errmsg);
    g_has_error = true;
    return NULL;
}

static void check_redeclaration(const char *name)
{
    entry_st *target = lookup_symbol(g_cur_scope_table, name);
    if (target != NULL) {
        char errmsg[200] = {};
        snprintf(errmsg, sizeof(errmsg),
            "%s redeclared in this block. previous declaration at line %d",
            name, target->lineno);
        yyerror(errmsg);
        g_has_error = true;
    }
}

static void check_func_redeclaration(const char *name)
{
    entry_st *target = lookup_symbol(g_root_table, name);
    if (target != NULL) {
        char errmsg[200] = {};
        snprintf(errmsg, sizeof(errmsg),
            "%s redeclared in this block. previous declaration at line %d",
            name, target->lineno);
        yyerror(errmsg);
        g_has_error = true;
    }
}

static const char *get_mnemonic(const type_et type, const op_et op)
{
    static const char *s_mnemonic[3][14] = {
        [kI_TYPE][kPOS_OP]="",     [kF_TYPE][kPOS_OP]="",
        [kI_TYPE][kADD_OP]="iadd", [kI_TYPE][kSUB_OP]="isub", [kI_TYPE][kMUL_OP]="imul", 
        [kI_TYPE][kQUO_OP]="idiv", [kI_TYPE][kREM_OP]="irem", [kI_TYPE][kNEG_OP]="ineg",
        [kF_TYPE][kADD_OP]="fadd", [kF_TYPE][kSUB_OP]="fsub", [kF_TYPE][kMUL_OP]="fmul", 
        [kF_TYPE][kQUO_OP]="fdiv", [kF_TYPE][kNEG_OP]="fneg",
        [kB_TYPE][kNOT_OP]="ixor",
        [kB_TYPE][kLEQ_OP]="ifle", [kB_TYPE][kGEQ_OP]="ifge", [kB_TYPE][kLSS_OP]="iflt",
        [kB_TYPE][kGTR_OP]="ifgt", [kB_TYPE][kEQL_OP]="ifeq", [kB_TYPE][kNEQ_OP]="ifne"
    };
    return s_mnemonic[type][op];
}

static void gen_cmp_expression(const op_et op, const type_et exptype)
{
    if (exptype == kI_TYPE) {
        CODEGEN("isub\n");
    } else if (exptype == kF_TYPE) {
        CODEGEN("fcmpl\n");
    }
    CODEGEN("%s L_cmp_%d\n", get_mnemonic(kB_TYPE, op), g_cmp_op_unique_label);
    CODEGEN("iconst_0\n");
    CODEGEN("goto L_cmp_%d\n", g_cmp_op_unique_label + 1);
    g_indent_cnt--;
    CODEGEN("L_cmp_%d :\n", g_cmp_op_unique_label++);
    g_indent_cnt++;
    CODEGEN("iconst_1\n");
    g_indent_cnt--;
    CODEGEN("L_cmp_%d :\n", g_cmp_op_unique_label++);
    g_indent_cnt++;
}

static void gen_ident_load(const container_st ctr)
{
    if (ctr.tc.type == kID_TYPE) {
        entry_st *ident = check_declaration(ctr.id_name);
        if (ident == NULL) {
            return;
        }
        switch (ident->type) {
            case kI_TYPE:
            case kB_TYPE:
                CODEGEN("iload %d\n", ident->address);
                break;
            case kF_TYPE:
                CODEGEN("fload %d\n", ident->address);
                break;
            case kS_TYPE:
                CODEGEN("aload %d\n", ident->address);
                break;
            case kA_TYPE:
                CODEGEN("aload %d\n", ident->address);
                CODEGEN("swap\n");
                switch (ident->element_type) {
                    case kI_TYPE:
                    case kB_TYPE:
                        CODEGEN("iaload\n");
                        break;
                    case kF_TYPE:
                        CODEGEN("faload\n");
                        break;
                    default:
                        return;
                }
                break;
            default:
                return;
        }
    }
}

static void gen_array_load(const container_st ctr)
{
    if (ctr.tc.type == kID_TYPE) {
        entry_st *ident = check_declaration(ctr.id_name);
        if (ident == NULL) {
            return;
        }
        switch (ident->type) {
            case kA_TYPE:
                CODEGEN("aload %d\n", ident->address);
                CODEGEN("swap\n");
                break;
            default:
                return;
        }
    }
}

static void gen_ident_store(const container_st ctr)
{
    
    if (ctr.tc.type == kID_TYPE) {
        entry_st *ident = check_declaration(ctr.id_name);
        if (ident == NULL) {
            return;
        }
        switch (ident->type) {
            case kI_TYPE:
            case kB_TYPE:
                CODEGEN("istore %d\n", ident->address);
                break;
            case kF_TYPE:
                CODEGEN("fstore %d\n", ident->address);
                break;
            case kS_TYPE:
                CODEGEN("astore %d\n", ident->address);
                break;
            case kA_TYPE:
                switch (ident->element_type) {
                    case kI_TYPE:
                    case kB_TYPE:
                        CODEGEN("iastore\n");
                        break;
                    case kF_TYPE:
                        CODEGEN("fastore\n");
                        break;
                    default:
                        return;
                }
                break;
            default:
                return;
        }
    }
}

static void gen_decl_statement(const int addr, const type_container_st tc, const bool has_init_val)
{
    switch (tc.type) {
        case kI_TYPE:
        case kB_TYPE:
            if (!has_init_val) {
                CODEGEN("ldc 0\n");
            }
            CODEGEN("istore %d\n", addr);
            break;
        case kF_TYPE:
            if (!has_init_val) {
                CODEGEN("ldc 0.0\n");
            }
            CODEGEN("fstore %d\n", addr);
            break;
        case kS_TYPE:
            if (!has_init_val) {
                CODEGEN("ldc \"\"\n");
            }
            CODEGEN("astore %d\n", addr);
            break;
        case kA_TYPE:
            switch (tc.element_type) {
                case kI_TYPE:
                case kB_TYPE:
                    CODEGEN("newarray int\n");
                    break;
                case kF_TYPE:
                    CODEGEN("newarray float\n");
                    break;
                default:
                    return;
            }
            CODEGEN("astore %d\n", addr);
            break;
        default:
            return;
    }
}

static void gen_print_statement(const op_et op, const type_et exptype)
{
    const char *java_type;
    switch (exptype) {
        case kB_TYPE:
            CODEGEN("ifne L_cmp_%d\n", g_cmp_op_unique_label);
            CODEGEN("ldc \"false\"\n");
            CODEGEN("goto L_cmp_%d\n", g_cmp_op_unique_label + 1);
            g_indent_cnt--;
            CODEGEN("L_cmp_%d:\n", g_cmp_op_unique_label++);
            g_indent_cnt++;
            CODEGEN("ldc \"true\"\n");
            g_indent_cnt--;
            CODEGEN("L_cmp_%d:\n", g_cmp_op_unique_label++);
            g_indent_cnt++;
            java_type = get_java_type(kS_TYPE);
            break;
        case kI_TYPE:
        case kF_TYPE:
        case kS_TYPE:
            java_type = get_java_type(exptype);
            break;
        default:
            return;
    }
    CODEGEN("getstatic java/lang/System/out Ljava/io/PrintStream;\n");
    CODEGEN("swap\n");
    if (op == kPRINT_OP) {
        CODEGEN("invokevirtual java/io/PrintStream/print(%s)V\n", java_type);
    } else if (op == kPRINTLN_OP) {
        CODEGEN("invokevirtual java/io/PrintStream/println(%s)V\n", java_type);
    }
}

static void gen_return_statement(const type_et exptype)
{
    switch (exptype) {
        case kI_TYPE:
        case kB_TYPE:
            CODEGEN("ireturn\n");
            break;
        case kF_TYPE:
            CODEGEN("freturn\n");
            break;
        default:
            P_LOG("no support `%s` for return statement yet.\n", get_type_name(exptype));
            return;
    }
}
