%{
#include <stdio.h>
#include <stdlib.h>

#include "def.h"
#include "sym_tab.h"
#include "ast.h"

/* stuff from lex */
extern int yylex();
extern char filename[256];
extern int lineno;

/* stuff for symbol table */
SYM_TAB curr_scope;

void yyerror(const char*);

%}

%union {
    /* for single character tokens */
    int c; 

    /* definition in def.h */
    struct Str str;
    struct Num num;

    char*  ident;
    char   charlit;
    struct astnode *astnode_p; /* definition in ast.h */
}


%token IDENT CHARLIT STRING NUMBER INDSEL PLUSPLUS MINUSMINUS SHL SHR LTEQ GTEQ 
%token EQEQ NOTEQ LOGAND LOGOR ELLIPSIS TIMESEQ DIVEQ MODEQ PLUSEQ MINUSEQ SHLEQ 
%token SHREQ ANDEQ OREQ XOREQ AUTO BREAK CASE CHAR CONST CONTINUE DEFAULT DO DOUBLE 
%token ELSE ENUM EXTERN FLOAT FOR GOTO IF INLINE INT LONG REGISTER RESTRICT RETURN 
%token SHORT SIGNED SIZEOF STATIC STRUCT SWITCH TYPEDEF UNION UNSIGNED VOID VOLATILE 
%token WHILE _BOOL _COMPLEX _IMAGINARY

/* https://en.cppreference.com/w/c/language/operator_precedence */
%left<c>    ','
%right<c>   '=' PLUSEQ MINUSEQ TIMESEQ DIVEQ MODEQ SHLEQ SHREQ ANDEQ XOREQ OREQ
%right<c>   '?' ':'
%left<c>    LOGOR
%left<c>    LOGAND
%left<c>    '|'
%left<c>    '^'
%left<c>    '&'
%left<c>    EQEQ NOTEQ
%left<c>    '<' LTEQ '>' GTEQ
%left<c>    SHR SHL
%left<c>    '+' '-'
%left<c>    '*' '/' '%'
%left<c>    '~' '!'
%left<c>     PLUSPLUS MINUSMINUS '(' ')' '.' '[' ']' INDSEL

/* values */
%type<ident>        IDENT 
%type<num>          NUMBER 
%type<charlit>      CHARLIT
%type<str>          STRING
%type<astnode_p>    constant

/* expressions */
%type<astnode_p>    expr
// %type<astnode_p>    const_expr 
%type<astnode_p>    assign_expr unary_expr cond_expr arith_expr cast_expr postfix_expr prim_expr //func_call

/* declarations */
/* delc: declarator */
%type<astnode_p>    declaration 
%type<astnode_p>    declaration_specs init_decl_list 
%type<astnode_p>    decl direct_decl
%type<astnode_p>    init_decl
%type<astnode_p>    pointer
%type<astnode_p>    param_type_list param_list param_declaration abstract_decl direct_abstract_decl 
%type<astnode_p>    ident_list
%type<astnode_p>    stg_class_spec type_spec declaration_spec  
%type<astnode_p>    func_spec type_qualif

/* statements */
// %type<astnode_p>    statement expr_stmnt
// %type<astnode_p>    label_stmnt //compound_stmnt selec_stmnt loop_stmnt jmp_stmnt

/* External Definitions */
%type<astnode_p>    translation_unit extern_declaration //func_def
// %type<astode_p>     decl_list


%%

translation_unit:     extern_declaration                                {} 
                    | translation_unit extern_declaration               {}
                    ;

extern_declaration:   declaration                                       {print_sym(curr_scope);}
                    // | func_def                                       {}
                    ;

declaration:      declaration_specs ';'                         {yyerror("Empty Declaration");}
                | declaration_specs init_decl_list ';'          {   
                                                                    // print_ast($2);
                                                                    sym_decl($1, $2);                                                                   
                                                                    // fprintf(stdout, "size %d\n", list_size($1));
                                                    /* loop through linked list and alloc and add symbol table entires */
                                                                    /* alloc_sym_ent(); sym_*/ }
                ;   

/* slight deviation from the c standard, but this is to avoid shit reduce conflicts */
declaration_specs:    declaration_spec                          {$$=alloc_list($1);}
                    | declaration_specs declaration_spec        {$$=list_append($2, $1);}
                    ;
declaration_spec:     stg_class_spec                            {$$=$1;}
                    | type_spec                                 {$$=$1;}
                    | type_qualif                               {$$=$1;} /* indicate that being ignored */
                    | func_spec                                 {$$=$1;}
                    ;

stg_class_spec:       AUTO                                      {$$=alloc_storage(STG_AUTO);    }
                    | STATIC                                    {$$=alloc_storage(STG_STATIC);  }
                    | EXTERN                                    {$$=alloc_storage(STG_EXTERN);  } 
                    | TYPEDEF                                   {$$=alloc_storage(STG_TYPEDEF); }
                    | REGISTER                                  {$$=alloc_storage(STG_REGISTER);}
                    ;

type_spec:        VOID                                          {$$=alloc_scalar(TYPE_VOID);    } 
                | CHAR                                          {$$=alloc_scalar(TYPE_CHAR);    } 
                | SHORT                                         {$$=alloc_scalar(TYPE_SHORT);   }  
                | INT                                           {$$=alloc_scalar(TYPE_INT);     } 
                | LONG                                          {$$=alloc_scalar(TYPE_LONG);    } 
                | FLOAT                                         {$$=alloc_scalar(TYPE_FLOAT);   }  
                | DOUBLE                                        {$$=alloc_scalar(TYPE_DOUBLE);  }    
                | SIGNED                                        {$$=alloc_scalar(TYPE_SIGNED);  }    
                | UNSIGNED                                      {$$=alloc_scalar(TYPE_UNSIGNED);}      
                | _BOOL                                         {$$=alloc_scalar(TYPE__BOOL);   }  
                | _COMPLEX                                      {$$=alloc_scalar(TYPE__COMPLEX);}      
                // | struct_union_spec
                // | enum_spec /* lmaooo noooo. */
                // | typedef_name /* you are funny if you think that I have time to worry about this */
                ; 

/* not handling type qualifiers and inline func specifier, so just quietly consume... */
type_qualif:          CONST                                     {$$=alloc_qualif(QUALIF_CONST);}
                    | RESTRICT                                  {$$=alloc_qualif(QUALIF_RESTRICT);}
                    | VOLATILE                                  {$$=alloc_qualif(QUALIF_VOLATILE);}
                    ;
func_spec:            INLINE                                    {$$=astnode_alloc(AST_FUNC_SPEC);};       

// type_qualif_list:     type_qualif                               
//                     | type_qualif_list type_qualif              
//                     ;

init_decl_list:   init_decl                                          {$$=alloc_list($1);}
                | init_decl_list ',' init_decl                       {$$=$1; list_append($3, $1);}
                ;

init_decl:        decl                                      {}            
                | decl '=' init /* not handling initializations for now... */ {}
                ;

init:             assign_expr
                ;

decl:             direct_decl                                   {$$=$1;}
                | pointer direct_decl                           {$$=last_ptr($1); 
                                                                 $$->ptr.ptr_to = $2;
                                                                 $$=$1;}
                ;

direct_decl:      IDENT                                         {$$=alloc_ident($1);} //{$$=alloc_list(alloc_ident($1));}
                | '(' decl ')'                                  {$$=$2;}
                | direct_decl '[' ']'                   /* array */
                | direct_decl '[' constant ']'          /* array */
                | direct_decl '(' param_type_list ')'   /* func */
                | direct_decl '(' ident_list ')'        /* func */
                | direct_decl '(' ')'                   /* func */
                ;

/* come back to pointers */
pointer:          '*'                                           {$$=alloc_ptr(NULL);} 
                | '*' pointer                                   {$$=alloc_ptr($2);} //{$$=list_append(alloc_ptr($2), $2);}
                // | '*' type_qualif_list                          {$$=alloc_ptr(NULL);}
                // | '*' type_qualif_list pointer                  {$$=alloc_ptr(NULL);}
                ;

param_type_list:      param_list                                {}
                    | param_list ',' ELLIPSIS                   {}
                    ;

param_list:           param_declaration                         {}
                    | param_list ',' param_declaration          {}
                    ;

param_declaration:    declaration_specs decl
                    | declaration_specs 
                    | declaration_specs abstract_decl
                    ;

abstract_decl:        pointer
                    | pointer direct_abstract_decl
                    | direct_abstract_decl
                    ;

direct_abstract_decl:     '(' abstract_decl ')'                 {$$=alloc_ident("TESTTESTTEST"); /* PLACE HOLDER FOR NOW!!!*/}
                        |  '[' ']'                              {$$=alloc_ident("TESTTESTTEST"); /* PLACE HOLDER FOR NOW!!!*/}
                        |  '[' constant ']'                     {$$=alloc_ident("TESTTESTTEST"); /* PLACE HOLDER FOR NOW!!!*/}
                        // |  direct_abstract_decl '[' type_qualif_list assign_expr ']'direct_abstract_decl
                        // |  direct_abstract_decl '[' type_qualif_list assign_expr ']'direct_abstract_decl
                        // |  direct_abstract_decl '[' type_qualif_list assign_expr ']'direct_abstract_decl
                        // |  direct_abstract_decl '[' type_qualif_list assign_expr ']'direct_abstract_decl
                        ;

ident_list:           IDENT                         {$$=alloc_ident("TESTTESTTEST");} /* alloc_list */
                    | ident_list ',' IDENT          {$$=alloc_ident("TESTTESTTEST");} /* list_append */
                    ;

// type_name:            spec_qualif_list 
//                     | spec_qualif_list abstract_decl
//                     ;


// /* statements... to be worked on later */
// statement:       expr_stmnt                                    {print_ast($1); putchar('\n');}
//                 | label_stmnt                               {$$=$1;}
//                 // | compound_stmnt                            {}
//                 // | selec_stmnt                               {}
//                 // | loop_stmnt                                {}
//                 // | jmp_stmnt                                 {}
//                 ;

// expr_stmnt:       expr ';'                                  {$$=$1;}

// label_stmnt:      IDENT ':' statement                       {$$=$3;}
//                 | CASE const_expr ':' statement              {$$=$4;}
//                 | DEFAULT ':' statement                     {$$=$3;}
//                 ;


// /* old stuff going to delete later
// //                   expr ';'                                  {print_ast($1); putchar('\n');}
// //                 | statement expr ';'                        {print_ast($2); putchar('\n');}
// */
expr:             assign_expr                               {$$=$1;}
                | expr ',' assign_expr                      {$$=alloc_binary(BINOP, $1, ',', $3);}
                ;

assign_expr:      unary_expr '=' assign_expr                {$$=alloc_binary(ASSIGN, $1, '=', $3);} 
                | unary_expr PLUSEQ assign_expr             {$$=alloc_and_expand_assignment($1, '+', $3);} 
                | unary_expr MINUSEQ assign_expr            {$$=alloc_and_expand_assignment($1, '-', $3);}     
                | unary_expr TIMESEQ assign_expr            {$$=alloc_and_expand_assignment($1, '*', $3);}     
                | unary_expr DIVEQ assign_expr              {$$=alloc_and_expand_assignment($1, '/', $3);}     
                | unary_expr MODEQ assign_expr              {$$=alloc_and_expand_assignment($1, '%', $3);}     
                | unary_expr SHLEQ assign_expr              {$$=alloc_and_expand_assignment($1, SHL, $3);}     
                | unary_expr SHREQ assign_expr              {$$=alloc_and_expand_assignment($1, SHR, $3);}     
                | unary_expr ANDEQ assign_expr              {$$=alloc_and_expand_assignment($1, '&', $3);}     
                | unary_expr XOREQ assign_expr              {$$=alloc_and_expand_assignment($1, '^', $3);}     
                | unary_expr OREQ assign_expr               {$$=alloc_and_expand_assignment($1, '|', $3);}     
                | cond_expr                                 {$$=$1;}
                ;

unary_expr:       postfix_expr                              {$$=$1;}
                | PLUSPLUS unary_expr                       {ASTNODE temp = alloc_num(1, 0.0, N_INT, N_SIGNED);
                                                                $$=alloc_and_expand_assignment($2, '+', temp);}
                | MINUSMINUS unary_expr                     {ASTNODE temp = alloc_num(1, 0.0, N_INT, N_SIGNED);
                                                                $$=alloc_and_expand_assignment($2, '-', temp);}
                | SIZEOF unary_expr                         {$$=alloc_sizeof($2);}
                | SIZEOF '(' unary_expr ')'                 {$$=alloc_sizeof($3);}
                | '&' cast_expr                             {$$=alloc_unary('&',$2);}
                | '*' cast_expr                             {$$=alloc_unary('*',$2);}
                | '+' cast_expr                             {$$=alloc_unary('+',$2);}
                | '-' cast_expr                             {$$=alloc_unary('-',$2);}
                | '~' cast_expr                             {$$=alloc_unary('~',$2);}
                | '!' cast_expr                             {$$=alloc_unary('!',$2);}
                ;

// const_expr:       cond_expr                                 {$$=$1;}
//                 ;

cond_expr:        arith_expr                                {$$=$1;}
                | arith_expr '?' expr ':' cond_expr         {$$=alloc_ternary($1, $3, $5);}
                ;

arith_expr:       arith_expr '+' arith_expr                 {$$=alloc_binary(BINOP,$1, '+', $3);} 
                | arith_expr '-' arith_expr                 {$$=alloc_binary(BINOP,$1, '-', $3);} 
                | arith_expr '*' arith_expr                 {$$=alloc_binary(BINOP,$1, '*', $3);} 
                | arith_expr '|' arith_expr                 {$$=alloc_binary(BINOP,$1, '|', $3);} 
                | arith_expr '^' arith_expr                 {$$=alloc_binary(BINOP,$1, '^', $3);} 
                | arith_expr '&' arith_expr                 {$$=alloc_binary(BINOP,$1, '&', $3);} 
                | arith_expr '%' arith_expr                 {$$=alloc_binary(BINOP,$1, '%', $3);} 
                | arith_expr '/' arith_expr                 {$$=alloc_binary(BINOP,$1, '/', $3);} 
                | arith_expr SHR arith_expr                 {$$=alloc_binary(BINOP,$1, SHR, $3);} 
                | arith_expr SHL arith_expr                 {$$=alloc_binary(BINOP,$1, SHL, $3);} 
                | arith_expr '<' arith_expr                 {$$=alloc_binary(BINOP,$1, '<', $3);}
                | arith_expr '>' arith_expr                 {$$=alloc_binary(BINOP,$1, '>', $3);}
                | arith_expr LTEQ arith_expr                {$$=alloc_binary(BINOP,$1, LTEQ, $3);}
                | arith_expr GTEQ arith_expr                {$$=alloc_binary(BINOP,$1, GTEQ, $3);}
                | arith_expr EQEQ arith_expr                {$$=alloc_binary(BINOP,$1, EQEQ, $3);}
                | arith_expr NOTEQ arith_expr               {$$=alloc_binary(BINOP,$1, NOTEQ, $3);}
                | arith_expr LOGAND arith_expr              {$$=alloc_binary(BINOP,$1, LOGAND, $3);}
                | arith_expr LOGOR arith_expr               {$$=alloc_binary(BINOP,$1, LOGOR, $3);}
                | arith_expr PLUSPLUS                       {$$=alloc_unary(PLUSPLUS,$1);} 
                | arith_expr MINUSMINUS                     {$$=alloc_unary(MINUSMINUS,$1);} 
                | '(' arith_expr ')'                        {$$=$2;}
                | cast_expr                                 {$$=$1;}
                ;

/*blank for now */
cast_expr:        unary_expr                                {$$=$1;}
                ;

postfix_expr:     prim_expr                                 {$$=$1;}
                | postfix_expr '[' expr ']'                 {$$=alloc_binary(BINOP, $1, '+', $3);
                                                                $$=alloc_unary('*', $$);}
                | postfix_expr '.' IDENT                    {$$=alloc_select($1, $3);}
                | postfix_expr INDSEL IDENT                 {$$=alloc_unary('*', $1);
                                                                $$=alloc_select($$, $3);}
                | postfix_expr '(' ')'                        {$$=alloc_fncall($1, NULL);}
                | postfix_expr '(' expr ')'                   {$$=alloc_fncall($1, $3);}
                // | '(' type_name ')' '{' init_list '}'       {/* shtuff */}
                // | '(' type_name ')' '{' init_list ',' '}'   {/* shtuff */}
                ;

// func_call:        postfix_expr '(' ')'                             {}
//                 |
//                 ;
                    
prim_expr:        IDENT                         {$$=alloc_ident($1);}
                | NUMBER                        {$$=alloc_num($1.int_num, $1.real, $1.type, $1.sign);}
                | CHARLIT                       {$$=alloc_charlit($1);}
                | STRING                        {$$=alloc_string($1.str, $1.len);}
                ;

constant:         NUMBER                        {$$=alloc_num($1.int_num, $1.real, $1.type, $1.sign);}
                | CHARLIT                       {$$=alloc_charlit($1);}
                // | enum_const
                ; 
%% 

void yyerror(const char *msg){
    fprintf(stderr, "Error: %s:%d %s\n", filename, lineno, msg);
}

int main(){

    /* creating global symbol table */
    curr_scope = sym_create(SCOPE_GLOBAL);

    yyparse();
    // print_sym(curr_scope);
    return 1;
}