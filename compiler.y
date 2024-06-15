    /* Definition section */
    %{
        #include "compiler_common.h"
        #include "compiler_util.h"
        #include <string.h>
        #include "main.h"
        #define MAX_SIZE 100

        typedef enum {
            OP_ADD,
            OP_SUB,
            OP_MUL,
            OP_DIV,
            OP_REM,
            OP_GTR,
            OP_LES,
            OP_GEQ,
            OP_LEQ,
            OP_EQL,
            OP_NEQ,
            OP_BNT,
            OP_INC_ASSIGN,
            OP_DEC_ASSIGN,
            
        } op_t;

        struct node {
            Object* obj;
            struct node* next;
        } ;

        const char* objectJavaTypeName[] = {
            [OBJECT_TYPE_VOID] = "V",
            [OBJECT_TYPE_BOOL] = "Z",
            [OBJECT_TYPE_INT] = "I",
            [OBJECT_TYPE_FLOAT] = "F",
            [OBJECT_TYPE_STR] = "Ljava/lang/String;",
        };


        typedef struct {
            Object* items[MAX_SIZE];
            int top;
        } Stack;
        Stack funcParStack;
        Stack inFunctionStack;

        struct node *scopeTable[50]={NULL};
        Object* funcObjTemp;
        int yydebug = 1;
        int scopeLevel = -1;
        int addrCount = 0;
        int itemsCount = 0;
        ObjectType typeTemp=0;
        
        //for jasmin
        int labelCount=0;
        void LOR_jas();
        void NOT_jas();
        void LAND_jas();

        void LGTR_jas();
        void LGTE_jas();
        void LLES_jas();
        void LLESE_jas();
        void fLGTR_jas();
        void fLGTE_jas();
        void fLLES_jas();
        void fLLESE_jas();
        void iEQ_jas();
        void iNE_jas();
        void val_ass_j(char* name);
        void add_ass_j(char* name);
        void sub_ass_j(char* name);
        void mul_ass_j(char* name);
        void div_ass_j(char* name);
        void rem_ass_j(char* name);
        void bor_ass_j(char* name);
        void ban_ass_j(char* name);
        void shl_ass_j(char* name);
        void shr_ass_j(char* name);

        void unary_jas(int op);
        void storeVariable_jas(char* variableName);
        void loadVariable_jas();

        //hw2
        void insertNode(struct node** table,int scopeLevel,struct node * target);
        void initialize(Stack *s);
        void push(Stack *s, Object* value);
        Object* pop(Stack *s);
        void DumpPar();
        void pushFunIntype(int type);
        const char* get_op_name(int op);
        void insertObj(char* name, ObjectType type, int addr,char* Func_sig);
        int get_addr(char* name);
        char* getTypeName(int type);
        void functionCall(char* name);
        void log_error(const char *filename, int error_number, const char *message);
    %}

    /* Variable or self-defined structure */
    %union {
        ObjectType var_type;

        bool b_var;
        int i_var;
        float f_var;
        char *s_var;
        int op;
        Object object_val;
    }

    /* Token without return */
    %token COUT
    %token SHR SHL BAN BOR BNT BXO ADD SUB MUL DIV REM NOT GTR LES GEQ LEQ EQL NEQ LAN LOR
    %token VAL_ASSIGN ADD_ASSIGN SUB_ASSIGN MUL_ASSIGN DIV_ASSIGN REM_ASSIGN BAN_ASSIGN BOR_ASSIGN BXO_ASSIGN SHR_ASSIGN SHL_ASSIGN INC_ASSIGN DEC_ASSIGN
    %token IF ELSE FOR WHILE RETURN BREAK CONTINUE

    /* Token with return, which need to sepcify type */
    %token <var_type> VARIABLE_T 
    %token <s_var> IDENT
    %token <b_var> BOOL_LIT
    %token <i_var> INT_LIT
    %token <f_var> FLOAT_LIT
    %token <s_var> STR_LIT

    /* Nonterminal with return, which need to sepcify type */
    %type <var_type> Expression CoutExpr AddExpr MulExpr LORExpr LANExpr LCOMExpr Exp_Var  INTExpr SHIFTExpr BORExpr BXORExpr BANExpr Cast_Exp_Var BOOLExpr IDENTExpr ARRExpr FunctionCall
    %type <op> AddOp EQOp UnaryOP
    %type <op> MulOp

    %left ADD SUB
    %left MUL DIV REM

    /* Yacc will start at this nonterminal */
    %start Program

    %%
    /* Grammar section */

    Program
        : { pushScope(); } GlobalStmtList { dumpScope(); }
        | /* Empty file */
    ;

    GlobalStmtList 
        : GlobalStmtList GlobalStmt
        | GlobalStmt
    ;

    GlobalStmt
        : DefineVariableStmt
        | FunctionDefStmt
    ;

    DefineVariableStmt
        : VARIABLE_T IDENT VAL_ASSIGN Expression ';'
        | VARIABLE_T IDENT ';'
    ;

    /* Function */
    FunctionDefStmt
        : VARIABLE_T IDENT '(' {initialize(&funcParStack);} FunctionParameterStmtList ')' { createFunction($<var_type>1, $<s_var>2); pushScope();DumpPar(); } '{' StmtList '}' {codeRaw("return");dumpScope();codeRaw(".end method");}
    ;
    FunctionParameterStmtList 
        : FunctionParameterStmtList ',' FunctionParameterStmt
        | FunctionParameterStmt
        | /* Empty function parameter */
    ;
    FunctionParameterStmt
        : VARIABLE_T IDENT { pushFunParm($<var_type>1, $<s_var>2, VAR_FLAG_DEFAULT); }
        | VARIABLE_T IDENT'['']' { pushFunParm($<var_type>1, $<s_var>2, VAR_FLAG_ARRAY); }
        
    ;

    /* Scope */
    StmtList 
        : StmtList Stmt
        | Stmt
    ;

    Stmt
        : ';'
        | { initialize(&inFunctionStack);}
           COUT CoutParmListStmt ';' { stdoutPrint();}
        | IF'(' Expression ')'  { printf("IF\n"); } IFStmt
        | WHILE { printf("WHILE\n");} '(' Expression ')'{ pushScope(); } '{' StmtList '}'{ dumpScope(); }
        | FOR { printf("FOR\n"); pushScope();} FORStmt  '{' StmtList '}' { dumpScope(); }
        | RETURN Expression ';' { printf("RETURN\n"); }
        | Def_variable ';' 
        | Assign_variable ';'
        | BREAK ';' {printf("BREAK\n");}
        | FunctionCall
    ;

    IFStmt
        : { pushScope(); }'{'StmtList '}'{ dumpScope(); } ELSEStmt
        | Stmt  ELSEStmt
        |//empty
    ;
    ELSEStmt
        :ELSE { printf("ELSE\n"); pushScope(); } '{' StmtList '}' { dumpScope(); } ELSEStmt
        |//empty
    ;

    FORStmt
        :'(' FORDef ';'Expression';' FORAssign ')'
        |'(' AutoIterator ')'//auto iterator
    ;
    
    FORDef
        :Def_variable
        |//empty
    ;

    AutoIterator
        : Def_variable
        |//empty
    ;

    FORAssign
        : Expression
        | Assign_variable
        |//empty
    ;

    Def_variable
        : VARIABLE_T {typeTemp=$<var_type>1;}  Variables /*int a*/
    ;

    Variables
        : Variables ',' IDENT {insertObj($<s_var>3, typeTemp, addrCount++,"-");}
        | IDENT { insertObj($<s_var>1, typeTemp, addrCount++,"-");}
        | IDENT VAL_ASSIGN Expression { 
           if(typeTemp != OBJECT_TYPE_AUTO) insertObj($<s_var>1, typeTemp, addrCount++,"-");
           else insertObj($<s_var>1, $<var_type>3, addrCount++,"-");
           val_ass_j($<s_var>1);
        } ',' Variables
        | IDENT VAL_ASSIGN Expression { 
           if(typeTemp != OBJECT_TYPE_AUTO) insertObj($<s_var>1, typeTemp, addrCount++,"-");
           else insertObj($<s_var>1, $<var_type>3, addrCount++,"-");
           val_ass_j($<s_var>1);
        } 
        | IDENT ':' IDENT{ 
            Object* obj = findVariable($<s_var>3);

            if(typeTemp != OBJECT_TYPE_AUTO) insertObj($<s_var>1, typeTemp, addrCount++,"-");
            else insertObj($<s_var>1, obj->type, addrCount++,"-");

           
            int addr=obj->symbol->addr;
            printf("IDENT (name=%s, address=%d)\n", $<s_var>3, addr);
        } 
        | IDENT '[' Exp_Var ']' VAL_ASSIGN '{' Items '}' { printf("create array: %d\n",itemsCount); insertObj($<s_var>1, typeTemp, addrCount++,"-"); itemsCount=0;}
        | IDENT '[' Exp_Var  ']' '[' Exp_Var ']' { insertObj($<s_var>1, typeTemp, addrCount++,"-");} /*2_D array*/
    ;

    Items
        : Exp_Var { itemsCount++; } ',' Items
        | Exp_Var { itemsCount++; }
        | /*empty*/
    ;

    Assign_variable
        : IDENT VAL_ASSIGN { printf("IDENT (name=%s, address=%d)\n",$<s_var>1,get_addr($<s_var>1)); } Expression { printf("EQL_ASSIGN\n");val_ass_j($<s_var>1);}
        | IDENT ADD_ASSIGN { printf("IDENT (name=%s, address=%d)\n",$<s_var>1,get_addr($<s_var>1)); } Expression { printf("ADD_ASSIGN\n");add_ass_j($<s_var>1);}
        | IDENT SUB_ASSIGN { printf("IDENT (name=%s, address=%d)\n",$<s_var>1,get_addr($<s_var>1)); } Expression { printf("SUB_ASSIGN\n");sub_ass_j($<s_var>1);}
        | IDENT MUL_ASSIGN { printf("IDENT (name=%s, address=%d)\n",$<s_var>1,get_addr($<s_var>1)); } Expression { printf("MUL_ASSIGN\n");mul_ass_j($<s_var>1);}
        | IDENT DIV_ASSIGN { printf("IDENT (name=%s, address=%d)\n",$<s_var>1,get_addr($<s_var>1)); } Expression { printf("DIV_ASSIGN\n");div_ass_j($<s_var>1);}
        | IDENT REM_ASSIGN { printf("IDENT (name=%s, address=%d)\n",$<s_var>1,get_addr($<s_var>1)); } Expression { printf("REM_ASSIGN\n");rem_ass_j($<s_var>1);}
        | IDENT BOR_ASSIGN { printf("IDENT (name=%s, address=%d)\n",$<s_var>1,get_addr($<s_var>1)); } Expression { printf("BOR_ASSIGN\n");bor_ass_j($<s_var>1);}
        | IDENT BAN_ASSIGN { printf("IDENT (name=%s, address=%d)\n",$<s_var>1,get_addr($<s_var>1)); } Expression { printf("BAN_ASSIGN\n");ban_ass_j($<s_var>1);}
        | IDENT SHL_ASSIGN { printf("IDENT (name=%s, address=%d)\n",$<s_var>1,get_addr($<s_var>1)); } Expression { printf("SHL_ASSIGN\n");shl_ass_j($<s_var>1);}
        | IDENT SHR_ASSIGN { printf("IDENT (name=%s, address=%d)\n",$<s_var>1,get_addr($<s_var>1)); } Expression { printf("SHR_ASSIGN\n");shr_ass_j($<s_var>1);}
        | IDENT '[' Exp_Var ']' VAL_ASSIGN { printf("IDENT (name=%s, address=%d)\n",$<s_var>1,get_addr($<s_var>1)); } Expression { printf("EQL_ASSIGN\n");} 
        | IDENT '[' Exp_Var ']' '[' Exp_Var ']' VAL_ASSIGN  { printf("IDENT (name=%s, address=%d)\n",$<s_var>1,get_addr($<s_var>1)); } Expression { printf("EQL_ASSIGN\n");} /*2_D array*/
    ;  


    CoutParmListStmt
        : CoutParmListStmt SHL  CoutExpr { pushFunIntype($<var_type>3); /*printf("%d cout\n",$<var_type>3);*/}
        | SHL CoutExpr { pushFunIntype($<var_type>2);/*printf("%d cout\n",$<var_type>2);*/}
    ;


    CoutExpr
        : AddExpr{ $<var_type>$=$<var_type>1;}
    ;


    Expression
        : LORExpr{ $<var_type>$=$<var_type>1;/*printf("%d expre\n",$<var_type>1);*/}
        |//empty expr
    ;


    


    LORExpr
        : LORExpr LOR LANExpr {
            printf("%s\n", "LOR");
            $<var_type>$=OBJECT_TYPE_BOOL;
            LOR_jas();
        }
        | LANExpr{ $<var_type>$=$<var_type>1;/*printf("%d lorex\n",$<var_type>1);*/}
    ;

    LANExpr
        : LANExpr LAN BORExpr {
            printf("%s\n", "LAN");
            $<var_type>$=OBJECT_TYPE_BOOL;
            LAND_jas();
        }
        | BORExpr{ $<var_type>$=$<var_type>1;/*printf("%d lanex\n",$<var_type>1);*/}
    ;

    BORExpr
        : BORExpr BOR BXORExpr{
            printf("%s\n", "BOR");
            //jas
            codeRaw("ior");
            if($<var_type>1==$<var_type>3){
                $<var_type>$=$<var_type>1;
            }else{
                if($<var_type>1==OBJECT_TYPE_BOOL||$<var_type>3==OBJECT_TYPE_BOOL){
                    $<var_type>$=OBJECT_TYPE_BOOL;
                }else if($<var_type>1==OBJECT_TYPE_FLOAT||$<var_type>3==OBJECT_TYPE_FLOAT){
                    $<var_type>$=OBJECT_TYPE_FLOAT;
                }else{
                    $<var_type>$=OBJECT_TYPE_VOID;
                }
                
            }
        }
        | BXORExpr { $<var_type>$=$<var_type>1;}
    ;

    BXORExpr
        : BXORExpr BXO BANExpr{
            printf("%s\n", "BXO");
            //jas
            codeRaw("ixor");
            if($<var_type>1==$<var_type>3){
                $<var_type>$=$<var_type>1;
            }else{
                if($<var_type>1==OBJECT_TYPE_BOOL||$<var_type>3==OBJECT_TYPE_BOOL){
                    $<var_type>$=OBJECT_TYPE_BOOL;
                }else if($<var_type>1==OBJECT_TYPE_FLOAT||$<var_type>3==OBJECT_TYPE_FLOAT){
                    $<var_type>$=OBJECT_TYPE_FLOAT;
                }else{
                    $<var_type>$=OBJECT_TYPE_VOID;
                }
                
            }
        }
        | BANExpr { $<var_type>$=$<var_type>1;}
    ;

    BANExpr
        : BANExpr BAN LCOMExpr{
            printf("%s\n", "BAN");
            //jas
            codeRaw("iand");
            if($<var_type>1==$<var_type>3){
                $<var_type>$=$<var_type>1;
            }else{
                if($<var_type>1==OBJECT_TYPE_BOOL||$<var_type>3==OBJECT_TYPE_BOOL){
                    $<var_type>$=OBJECT_TYPE_BOOL;
                }else if($<var_type>1==OBJECT_TYPE_FLOAT||$<var_type>3==OBJECT_TYPE_FLOAT){
                    $<var_type>$=OBJECT_TYPE_FLOAT;
                }else{
                    $<var_type>$=OBJECT_TYPE_VOID;
                }
                
            }
        } 
        | LCOMExpr { $<var_type>$=$<var_type>1;}
    ;


    LCOMExpr
        : LCOMExpr LCOMOp SHIFTExpr {
            printf("%s\n", get_op_name($<op>2));

            //jasmin
            if($<var_type>1==OBJECT_TYPE_INT){
                if(strcmp(get_op_name($<op>2),"GTR")==0){
                    LGTR_jas();
                }else if(strcmp(get_op_name($<op>2),"LES")==0){
                    LLES_jas();
                }else if(strcmp(get_op_name($<op>2),"GEQ")==0){
                    LGTE_jas();
                }else if(strcmp(get_op_name($<op>2),"LEQ")==0){
                    LLESE_jas();
                }
            }else{
                if(strcmp(get_op_name($<op>2),"GTR")==0){
                    fLGTR_jas();
                }else if(strcmp(get_op_name($<op>2),"LES")==0){
                    fLLES_jas();
                }else if(strcmp(get_op_name($<op>2),"GEQ")==0){
                    fLGTE_jas();
                }else if(strcmp(get_op_name($<op>2),"LEQ")==0){
                    fLLESE_jas();
                }
            }
            

            $<var_type>$=OBJECT_TYPE_BOOL;

        }
        | LCOMExpr EQOp SHIFTExpr{
            printf("%s\n", get_op_name($<op>2));
            
            if(strcmp(get_op_name($<op>2),"EQL")==0){
                iEQ_jas();
            }else if(strcmp(get_op_name($<op>2),"NEQ")==0){
                iNE_jas();
            }

            if($<var_type>1==$<var_type>3){
                $<var_type>$=$<var_type>1;
                //printf("%d %daddexpr\n",$<var_type>1,$<var_type>3 );
            }else{
                if($<var_type>1==OBJECT_TYPE_BOOL||$<var_type>3==OBJECT_TYPE_BOOL){
                    $<var_type>$=OBJECT_TYPE_BOOL;
                }else if($<var_type>1==OBJECT_TYPE_FLOAT||$<var_type>3==OBJECT_TYPE_FLOAT){
                    $<var_type>$=OBJECT_TYPE_FLOAT;
                }else{
                    $<var_type>$=OBJECT_TYPE_VOID;
                }
            }
        }
        | SHIFTExpr{ $<var_type>$=$<var_type>1;/*printf("%d lanex\n",$<var_type>1);*/}
    ;

    LCOMOp
        : GTR{ $<op>$ = OP_GTR; }
        | LES{ $<op>$ = OP_LES; } 
        | GEQ{ $<op>$ = OP_GEQ; }
        | LEQ{ $<op>$ = OP_LEQ; }
    ;

    EQOp
        : EQL{ $<op>$ = OP_EQL; }
        | NEQ{ $<op>$ = OP_NEQ; }
    ;

    SHIFTExpr
        : SHIFTExpr SHL AddExpr{
            printf("SHL\n");
            //jas
            codeRaw("ishl");
            if($<var_type>1==$<var_type>3){
                $<var_type>$=$<var_type>1;
                //printf("%d %daddexpr\n",$<var_type>1,$<var_type>3 );
            }else{
                if($<var_type>1==OBJECT_TYPE_BOOL||$<var_type>3==OBJECT_TYPE_BOOL){
                    $<var_type>$=OBJECT_TYPE_BOOL;
                }else if($<var_type>1==OBJECT_TYPE_FLOAT||$<var_type>3==OBJECT_TYPE_FLOAT){
                    $<var_type>$=OBJECT_TYPE_FLOAT;
                }else{
                    $<var_type>$=OBJECT_TYPE_VOID;
                }
            }
        }
        | SHIFTExpr SHR AddExpr{
            printf("SHR\n");
            
            codeRaw("ishr");
            if($<var_type>1==$<var_type>3){
                $<var_type>$=$<var_type>1;
                //printf("%d %daddexpr\n",$<var_type>1,$<var_type>3 );
            }else{
                if($<var_type>1==OBJECT_TYPE_BOOL||$<var_type>3==OBJECT_TYPE_BOOL){
                    $<var_type>$=OBJECT_TYPE_BOOL;
                }else if($<var_type>1==OBJECT_TYPE_FLOAT||$<var_type>3==OBJECT_TYPE_FLOAT){
                    $<var_type>$=OBJECT_TYPE_FLOAT;
                }else{
                    $<var_type>$=OBJECT_TYPE_VOID;
                }
            }
        }
        | AddExpr{ $<var_type>$=$<var_type>1;}
    ;

    AddExpr
        : AddExpr AddOp MulExpr {
            printf("%s\n", get_op_name($<op>2));
            //jasmin
            
            if($<var_type>1==OBJECT_TYPE_FLOAT||$<var_type>3==OBJECT_TYPE_FLOAT){
                if(strcmp(get_op_name($<op>2),"ADD")==0){
                    codeRaw("fadd");
                }else{
                    codeRaw("fsub");
                }
            }else{//int
                if(strcmp(get_op_name($<op>2),"ADD")==0){
                    codeRaw("iadd");
                }else{
                    codeRaw("isub");
                }
            }
            

            if($<var_type>1==$<var_type>3){
                $<var_type>$=$<var_type>1;
                //printf("%d %daddexpr\n",$<var_type>1,$<var_type>3 );
            }else{
                if($<var_type>1==OBJECT_TYPE_BOOL||$<var_type>3==OBJECT_TYPE_BOOL){
                    $<var_type>$=OBJECT_TYPE_BOOL;
                }else if($<var_type>1==OBJECT_TYPE_FLOAT||$<var_type>3==OBJECT_TYPE_FLOAT){
                    $<var_type>$=OBJECT_TYPE_FLOAT;
                }else{
                    $<var_type>$=OBJECT_TYPE_VOID;
                }
            }
        }
        | MulExpr{ $<var_type>$=$<var_type>1;}
    ;

    AddOp
        : ADD  {
            $<op>$ = OP_ADD;
            
        }
        | SUB {
            $<op>$ = OP_SUB;
            
        }
    ;

    MulExpr
        : MulExpr MulOp Cast_Exp_Var {
            printf("%s\n", get_op_name($<op>2));
            if($<var_type>1==OBJECT_TYPE_FLOAT||$<var_type>3==OBJECT_TYPE_FLOAT){
                if(strcmp(get_op_name($<op>2),"MUL")==0){
                    codeRaw("fmul");
                }else if(strcmp(get_op_name($<op>2),"DIV")==0){
                    codeRaw("fdiv");
                }
            }else{//int
                if(strcmp(get_op_name($<op>2),"MUL")==0){
                    codeRaw("imul");
                }else if(strcmp(get_op_name($<op>2),"DIV")==0){
                    codeRaw("idiv");
                }else{
                    codeRaw("irem");
                }
            }
            

            if($<var_type>1==$<var_type>3){
                $<var_type>$=$<var_type>1;
            }else{
                if($<var_type>1==OBJECT_TYPE_BOOL||$<var_type>3==OBJECT_TYPE_BOOL){
                    $<var_type>$=OBJECT_TYPE_BOOL;
                }else if($<var_type>1==OBJECT_TYPE_FLOAT||$<var_type>3==OBJECT_TYPE_FLOAT){
                    $<var_type>$=OBJECT_TYPE_FLOAT;
                }else{
                    $<var_type>$=OBJECT_TYPE_VOID;
                }
            }
            
        }
        | Cast_Exp_Var{ $<var_type>$=$<var_type>1;}
    ;

    MulOp
        : MUL {
            $<op>$ = OP_MUL;
        }
        | DIV {
            $<op>$ = OP_DIV;
        }
        | REM{
            $<op>$ = OP_REM;
        }
    ;

    Cast_Exp_Var
        : '(' VARIABLE_T ')'Exp_Var {printf("Cast to %s\n",getTypeName($<var_type>2));$<var_type>$=$<var_type>4;}
        | Exp_Var{$<var_type>$=$<var_type>1;}
    ;

    Exp_Var
        : INTExpr {$<var_type>$=OBJECT_TYPE_INT;}
        | SUB INT_LIT {printf("INT_LIT %d\nNEG\n",$<i_var>2);$<var_type>$=OBJECT_TYPE_INT;code("ldc %d",$<i_var>2);codeRaw("ineg");}
        | FLOAT_LIT {printf("FLOAT_LIT %f\n",$<f_var>1);$<var_type>$=OBJECT_TYPE_FLOAT;code("ldc %f",$<f_var>1);}
        | SUB FLOAT_LIT {printf("FLOAT_LIT %f\nNEG\n",$<f_var>2);$<var_type>$=OBJECT_TYPE_FLOAT;code("ldc %f",$<f_var>2);codeRaw("fneg");}
        | BOOLExpr{ $<var_type>$=OBJECT_TYPE_BOOL;}
        | STR_LIT { printf("STR_LIT \"%s\"\n",$<s_var>1); $<var_type>$=OBJECT_TYPE_STR;
                    code("ldc \"%s\"",$<s_var>1);}
        | IDENTExpr {$<var_type>$=$<var_type>1;}
        | ARRExpr{ $<var_type>$=$<var_type>1; }
        | '(' Expression ')'{ $<var_type>$=$<var_type>2;/*printf("%d opereand\n",$<var_type>2);*/}
        | FunctionCall {$<var_type>$=$<var_type>1;}
    ;

    BOOLExpr
        : NOT BOOLExpr{printf("NOT\n");$<var_type>$=OBJECT_TYPE_BOOL;NOT_jas();}
        | BOOL_LIT {if($<b_var>1){
                printf("BOOL_LIT TRUE\n");
                codeRaw("iconst_1");
            }else{ 
                printf("BOOL_LIT FALSE\n");
                codeRaw("iconst_0");
            }$<var_type>$=OBJECT_TYPE_BOOL;}
    ;

    INTExpr
        : UnaryOP INTExpr{printf("%s\n", get_op_name($<op>1));unary_jas($<op>1);}
        | INTExpr UnaryOP{printf("%s\n", get_op_name($<op>2));unary_jas($<op>1);}
        | INT_LIT{printf("INT_LIT %d\n",$<i_var>1);code("ldc %d",$<i_var>1);}
    ;

    ARRExpr
        : IDENT '['Exp_Var']'{
            if(strcmp($<s_var>1,"endl")==0){
                printf(" (name=endl, address=-1)\n");
                $<var_type>$=OBJECT_TYPE_STR;
                
            }else{
                Object* obj = findVariable($<s_var>1);
                int addr=obj->symbol->addr;
                printf("IDENT (name=%s, address=%d)\n", $<s_var>1, addr);
                $<var_type>$=obj->type;
            }
        }
    ;

    IDENTExpr
        : UnaryOP IDENTExpr{printf("%s\n", get_op_name($<op>1));unary_jas($<op>1);}
        | IDENTExpr UnaryOP {printf("%s\n", get_op_name($<op>2));unary_jas($<op>1);}
        | IDENT {
            if(strcmp($<s_var>1,"endl")==0){
                printf("IDENT (name=endl, address=-1)\n");
                $<var_type>$=OBJECT_TYPE_STR;
                //jasmin
                codeRaw("ldc \"\\n\"");
            }else{
                Object* obj = findVariable($<s_var>1);
                //jasmin
                loadVariable_jas($<s_var>1);

                int addr=obj->symbol->addr;
                printf("IDENT (name=%s, address=%d)\n", $<s_var>1, addr);
                $<var_type>$=obj->type;
            }
        }
        | IDENT '[' Exp_Var ']' '[' Exp_Var ']' { 
            printf("IDENT (name=%s, address=%d)\n",$<s_var>1,get_addr($<s_var>1));
            $<var_type>$=findVariable($<s_var>1)->type; 
        }
    ;

    UnaryOP
        : BNT{$<op>$=OP_BNT;}
        | INC_ASSIGN {$<op>$=OP_INC_ASSIGN;}
        | DEC_ASSIGN {$<op>$=OP_DEC_ASSIGN;}
    ;

    FunctionCall
        : IDENT '(' FuncCallPars ')' {functionCall($<s_var>1); $<var_type>$=findVariable($<s_var>1)->symbol->func_var;}
    ;

    FuncCallPars
        : FuncCallPars ',' Expression 
        | Expression
    ;

    %%
    /* C code section */

    void pushScope() {
        scopeLevel++;
        printf("> Create symbol table (scope level %d)\n",scopeLevel);
    }

    void dumpScope() {
        printf("\n> Dump symbol table (scope level: %d)\n",scopeLevel);
        printf("Index     Name                Type      Addr      Lineno    Func_sig  \n");
        struct node* head = scopeTable[scopeLevel];
        int idx=0;
        while(head!=NULL){
            char* type="";
            switch(head->obj->type) {
                case OBJECT_TYPE_INT:
                    type="int";
                    break;
                case OBJECT_TYPE_FLOAT:
                    type="float";
                    break;
                case OBJECT_TYPE_DOUBLE:
                    type="double";
                    break;
                case OBJECT_TYPE_BOOL:
                    type="bool";
                    break;
                case OBJECT_TYPE_STR:
                    type="string";
                    break;
                case OBJECT_TYPE_FUNCTION:
                    type="function";
                    break;
                default:
                    type="unknown";
                    break;
            }
        //printf("Index     Name                Type      Addr      Lineno    Func_sig  \n");
            printf("%-10d%-20s%-10s%-10ld%-10d%-10s\n",idx,head->obj->symbol->name,type,head->obj->symbol->addr,head->obj->symbol->lineno,head->obj->symbol->func_sig);
            idx++;
            head= head->next;
        }
        
        scopeTable[scopeLevel]=NULL;
        scopeLevel--;
    }

    Object* createVariable(ObjectType variableType, char* variableName, int variableFlag) {
        return NULL;
    }

    void pushFunParm(ObjectType variableType, char* variableName, int variableFlag) {
        //printf("> Insert `%s` (addr: %d) to scope level %d\n",variableName,addrCountTb[scopeLevel],scopeLevel);


        Object* obj=malloc(sizeof(Object));
        
        obj->type=variableType;

        obj->symbol=malloc(sizeof(SymbolData));
        obj->symbol->name=variableName;
        obj->symbol->index=0;
        obj->symbol->addr=addrCount++;
        obj->symbol->lineno=yylineno;
        obj->symbol->func_sig=(char *)malloc(MAX_SIZE * sizeof(char));

        switch(variableType) {//for the real function_sig
            case OBJECT_TYPE_INT:
                strcpy(obj->symbol->func_sig,"I");
                break;
            case OBJECT_TYPE_VOID:
                strcpy(obj->symbol->func_sig,"V");
                break;
            case OBJECT_TYPE_STR:
                strcpy(obj->symbol->func_sig,"Ljava/lang/String;");
                break;
            case OBJECT_TYPE_BOOL:
                strcpy(obj->symbol->func_sig,"Z");
                break;
            default:
                strcpy(obj->symbol->func_sig,"?");
                break;
        }
        
        if(variableFlag==VAR_FLAG_ARRAY){
            char temp[50]="[";
            strcat(temp,obj->symbol->func_sig);
            strcpy(obj->symbol->func_sig,temp);
        }
        
        funcObjTemp=obj;
        struct node* n=malloc(sizeof(struct node));
        n->obj=obj;
        push(&funcParStack,obj);
    }

    void DumpPar(){
        int top=funcParStack.top;
        for(int i=0;i<=top;i++){
            Object* obj= funcParStack.items[i];
            printf("> Insert `%s` (addr: %ld) to scope level %d\n",obj->symbol->name,obj->symbol->addr,scopeLevel);
            struct node* n=malloc(sizeof(struct node));
            n->obj=obj;
            insertNode(scopeTable,scopeLevel,n);
        }
    }

    void createFunction(ObjectType variableType, char* funcName) {
        printf("func: %s\n",funcName);
        printf("> Insert `%s` (addr: -1) to scope level %d\n",funcName,scopeLevel);
        
        Object* obj=malloc(sizeof(Object));
        
        obj->type=OBJECT_TYPE_FUNCTION;

        obj->symbol=malloc(sizeof(SymbolData));
        obj->symbol->name=funcName;
        obj->symbol->index=0;
        obj->symbol->func_sig=(char *)malloc(MAX_SIZE * sizeof(char));
        obj->symbol->addr=-1;
        obj->symbol->lineno=yylineno;
        obj->symbol->func_var=variableType;
        switch(variableType) {
            case OBJECT_TYPE_INT:
                strcpy(obj->symbol->func_sig,"I");
                break;
            case OBJECT_TYPE_VOID:
                strcpy(obj->symbol->func_sig,"V");
                break;
            case OBJECT_TYPE_STR:
                strcpy(obj->symbol->func_sig,"Ljava/lang/String;");
                break;
            case OBJECT_TYPE_BOOL:
                strcpy(obj->symbol->func_sig,"Z");
                break;
            default:
                strcpy(obj->symbol->func_sig,"?");
                break;
        }
        char tempstr[50]=")";
        strcat(tempstr, obj->symbol->func_sig);
        for(int i=funcParStack.top; i>=0; i--) {
            strcat(funcParStack.items[i]->symbol->func_sig,tempstr);
            strcpy(tempstr,funcParStack.items[i]->symbol->func_sig);
            funcParStack.items[i]->symbol->func_sig="-";
        }
        char temp[50]="(";
        strcat(temp,tempstr);
        strcpy(obj->symbol->func_sig,temp);
        

        funcObjTemp=obj;
        struct node* n=malloc(sizeof(struct node));
        n->obj=obj;
        insertNode(scopeTable,scopeLevel,n);

        //jasmin
        if(strcmp(funcName,"main")==0){
            codeRaw(".method public static main([Ljava/lang/String;)V");
            codeRaw(".limit stack 100");
            codeRaw(".limit locals 100");
        }

    }


    void functionCall(char* name){
        Object* obj = findVariable(name);
        printf("IDENT (name=%s, address=-1)\n",name);
        printf("call: %s%s\n",name,obj->symbol->func_sig);
    }

    void insertObj(char* name, ObjectType type, int addr,char* Func_sig) {
        printf("> Insert `%s` (addr: %d) to scope level %d\n",name,addr,scopeLevel);
        
        Object* obj=malloc(sizeof(Object));
        
        obj->type=type;

        obj->symbol=malloc(sizeof(SymbolData));
        obj->symbol->name=name;
        obj->symbol->index=0;
        obj->symbol->func_sig=Func_sig;
        obj->symbol->addr=addr;
        obj->symbol->lineno=yylineno;
        
        struct node* n=malloc(sizeof(struct node));
        n->obj=obj;
        insertNode(scopeTable,scopeLevel,n);

        
    }


    const char* get_op_name(int op) {
        switch (op) {
            case OP_ADD:
                return "ADD";
            case OP_SUB:
                return "SUB";
            case OP_MUL:
                return "MUL";
            case OP_DIV:
                return "DIV";
            case OP_REM:
                return "REM";
            case OP_GTR:
                return "GTR";
            case OP_LES:
                return "LES";
            case OP_GEQ:
                return "GEQ";
            case OP_LEQ:
                return "LEQ";
            case OP_EQL:
                return "EQL";
            case OP_NEQ:
                return "NEQ";
            case OP_BNT:
                return "BNT";
            case OP_INC_ASSIGN:
                return "INC_ASSIGN";
            case OP_DEC_ASSIGN:
                return "DEC_ASSIGN";
            default:
                return "unknown";
        }
    }

    Object* findVariable(char* variableName) {
        Object* variable = NULL;
        for(int i = scopeLevel; i >=0;i--){
            struct node* now=scopeTable[i];

            while(now!=NULL){
                if(strcmp(now->obj->symbol->name, variableName)==0){
                    variable=now->obj;
                    break;
                }
                now=now->next;
            }
            if(variable!=NULL){
                break;
            }
        }
        //jasmin
        

        return variable;
    }

    int get_addr(char* name){
        return findVariable(name)->symbol->addr;
    }

    void pushFunIntype(int type){
        Object* obj=malloc(sizeof(Object));
        
        obj->type=type;

        obj->symbol=malloc(sizeof(SymbolData));
        //obj->symbol->name=funcName;
        
        obj->symbol->index=0;
    
        //obj->symbol->addr=;
        obj->symbol->lineno=yylineno;
        push(&inFunctionStack,obj);

        //jasmin
        //log_error("error.txt", type, objectJavaTypeName[type]);
        codeRaw("getstatic java/lang/System/out Ljava/io/PrintStream;"); 
        codeRaw("swap"); 
        code("invokevirtual java/io/PrintStream/print(%s)V",objectJavaTypeName[type]);

    }
    

    void stdoutPrint() {
        printf("cout");
        for (int i = 0; i <= inFunctionStack.top;i++){
            ObjectType type=inFunctionStack.items[i]->type;
            switch(type) {
                case OBJECT_TYPE_INT:
                    printf(" int");
                    break;
                case OBJECT_TYPE_FLOAT:
                    printf(" float");
                    break;
                case OBJECT_TYPE_DOUBLE:
                    printf(" double");
                    break;
                case OBJECT_TYPE_BOOL:
                    printf(" bool");
                    break;
                case OBJECT_TYPE_STR:
                    printf(" string");
                    break;
                case OBJECT_TYPE_VOID:
                    printf(" void");
                    break;
                default:
                    printf(" %d",type);
                    break;
            }
        }
        printf("\n");

        
    }

    char* getTypeName(int type) {
        switch(type) {
                case OBJECT_TYPE_INT:
                    return "int";
                    break;
                case OBJECT_TYPE_FLOAT:
                    return "float";
                    break;
                case OBJECT_TYPE_DOUBLE:
                    return "double";
                    break;
                case OBJECT_TYPE_BOOL:
                    return "bool";
                    break;
                case OBJECT_TYPE_STR:
                    return "string";
                    break;
                case OBJECT_TYPE_VOID:
                    return "void";
                    break;
                default:
                    return "idk";
                    break;
            }
    }

    //linkList function
    void insertNode(struct node** table,int scopeLevel,struct node * target){
        if(table[scopeLevel]==NULL){
            table[scopeLevel] = target;
            return;
        }

        struct node* head= table[scopeLevel];

        while(head->next!=NULL){
            head= head->next;
        }
        head->next= target;
        return;
    }

    bool isIdentExists(struct node** table,int scopeLevel,char* Name){
        if(table[scopeLevel]==NULL){
            return false;
        }
        struct node* head= table[scopeLevel];

        while(head!=NULL){
            if(head->obj->symbol->name==Name)return true;
            head= head->next;
        }
        return false;

    }



    //Stack function
    void initialize(Stack *s) {
        s->top = -1;
    }

    void push(Stack *s, Object* value) {
        if (s->top==MAX_SIZE-1) {
            printf("Stack is full. Cannot push.\n");
            return;
        }
        s->items[++s->top] = value;
    }

    Object* pop(Stack *s) {
        if (s->top==-1) {
            printf("Stack is empty. Cannot pop.\n");
        }
        return s->items[s->top--];
    }
    //debug
    void log_error(const char *filename, int error_number, const char *message) {
    FILE *file = fopen(filename, "a"); // Open the file in append mode
    if (file == NULL) {
        perror("Error opening file");
        return;
    }

    // Write the error number and error message to the file
    fprintf(file, "Error %d: %s\n", error_number, message);

    fclose(file); // Close the file
    }

    //jasmin

    void LOR_jas(){
        code(
    ";OR\n\
    istore 0 ; 将 v1 存储到本地变量0中\n\
    istore 1 ; 将 v2 存储到本地变量1中\n\
    iload 0   ; 将本地变量0（即 v1）加载到栈顶\n\
    ifne LTrue%d\n\
    iload 1   ; 将本地变量0（即 v1）加载到栈顶\n\
    ifne LTrue%d\n\
    iconst_0\n\
    goto LEnd%d\n\
LTrue%d:\n\
    iconst_1\n\
LEnd%d:\n\
        ",labelCount,labelCount,labelCount,labelCount,labelCount);
        labelCount++;
    }

    void NOT_jas(){
        code(
    ";NOT\n\
    ifeq LTrue%d\n\
    iconst_0\n\
    goto LEnd%d\n\
LTrue%d:\n\
    iconst_1\n\
LEnd%d:\n\
        ",labelCount,labelCount,labelCount,labelCount);
        labelCount++;
    }

    void LAND_jas(){
        code(
    ";AND\n\
    istore 0 ; 将 v1 存储到本地变量0中\n\
    istore 1 ; 将 v2 存储到本地变量1中\n\
    iload 0   ; 将本地变量0（即 v1）加载到栈顶\n\
    ifeq LFalse%d\n\
    iload 1   ; 将本地变量0（即 v1）加载到栈顶\n\
    ifeq LFalse%d\n\
    iconst_1\n\
    goto LEnd%d\n\
LFalse%d:\n\
    iconst_0\n\
LEnd%d:\n\
        ",labelCount,labelCount,labelCount,labelCount,labelCount);
        labelCount++;
    }
    //jas_cmp
    void LGTR_jas(){
        code(";GTR\n\
    if_icmpgt LTrue%d\n\
    iconst_0\n\
    goto LEnd%d\n\
LTrue%d:\n\
    iconst_1\n\
LEnd%d:\n\
",labelCount,labelCount,labelCount,labelCount);
        labelCount++;
    }

    void fLGTR_jas(){
        code(";GTR\n\
    fcmpg ; 将栈顶的两个浮点数进行比较，将结果压入操作数栈（1: 大于，0: 等于，-1: 小于)\n\
    ifgt LTrue%d\n\
    iconst_0\n\
    goto LEnd%d\n\
LTrue%d:\n\
    iconst_1\n\
LEnd%d:\n\
",labelCount,labelCount,labelCount,labelCount);
        labelCount++;
    }

    void LLES_jas(){
        code(";LES\n\
    if_icmplt LTrue%d\n\
    iconst_0\n\
    goto LEnd%d\n\
LTrue%d:\n\
    iconst_1\n\
LEnd%d:\n\
        ",labelCount,labelCount,labelCount,labelCount);
        labelCount++;
    }

    void fLLES_jas(){
        code(";LES\n\
    fcmpg ; 将栈顶的两个浮点数进行比较，将结果压入操作数栈（1: 大于，0: 等于，-1: 小于)\n\
    iflt LTrue%d\n\
    iconst_0\n\
    goto LEnd%d\n\
LTrue%d:\n\
    iconst_1\n\
LEnd%d:\n\
        ",labelCount,labelCount,labelCount,labelCount);
        labelCount++;
    }

    void LGTE_jas(){
        code(";GTEQ\n\
    if_icmpge LTrue%d\n\
    iconst_0\n\
    goto LEnd%d\n\
LTrue%d:\n\
    iconst_1\n\
LEnd%d:\n\
        ",labelCount,labelCount,labelCount,labelCount);
        labelCount++;
    }

    void fLGTE_jas(){
        code(";GTEQ\n\
    fcmpg ; 将栈顶的两个浮点数进行比较，将结果压入操作数栈（1: 大于，0: 等于，-1: 小于)\n\
    ifge LTrue%d\n\
    iconst_0\n\
    goto LEnd%d\n\
LTrue%d:\n\
    iconst_1\n\
LEnd%d:\n\
        ",labelCount,labelCount,labelCount,labelCount);
        labelCount++;
    }

    void fLLESE_jas(){
        code(";LEQ\n\
    fcmpg ; 将栈顶的两个浮点数进行比较，将结果压入操作数栈（1: 大于，0: 等于，-1: 小于)\n\
    ifle LTrue%d\n\
    iconst_0\n\
    goto LEnd%d\n\
LTrue%d:\n\
    iconst_1\n\
LEnd%d:\n\
        ",labelCount,labelCount,labelCount,labelCount);
        labelCount++;
    }

    void LLESE_jas(){
        code(";LEQ\n\
    if_icmple LTrue%d\n\
    iconst_0\n\
    goto LEnd%d\n\
LTrue%d:\n\
    iconst_1\n\
LEnd%d:\n\
        ",labelCount,labelCount,labelCount,labelCount);
        labelCount++;
    }

    void iEQ_jas(){
        code(";EQ\n\
    if_icmpeq LTrue%d\n\
    iconst_0\n\
    goto LEnd%d\n\
LTrue%d:\n\
    iconst_1\n\
LEnd%d:\n\
        ",labelCount,labelCount,labelCount,labelCount);
        labelCount++;
    }

    void iNE_jas(){
        code(";NEQ\n\
    if_icmpne LTrue%d\n\
    iconst_0\n\
    goto LEnd%d\n\
LTrue%d:\n\
    iconst_1\n\
LEnd%d:\n\
        ",labelCount,labelCount,labelCount,labelCount);
        labelCount++;
    }

    //jasmin assign func
    //the expression value is already on top of the stack
    void val_ass_j(char* name){
        //loadVariable_jas(name);
        storeVariable_jas(name);
    }

    void add_ass_j(char* name){
        loadVariable_jas(name);
        codeRaw("swap");
        if(findVariable(name)->type==OBJECT_TYPE_FLOAT){

            codeRaw("fadd");
        
        }else{//int

            codeRaw("iadd");
            
        }
        
        storeVariable_jas(name);
    }

    void sub_ass_j(char* name){
        loadVariable_jas(name);
        codeRaw("swap");
        if(findVariable(name)->type==OBJECT_TYPE_FLOAT){

            codeRaw("fsub");
        
        }else{//int

            codeRaw("isub");
            
        }
        
        storeVariable_jas(name);
    }

    void mul_ass_j(char* name){
        loadVariable_jas(name);
        codeRaw("swap");
        if(findVariable(name)->type==OBJECT_TYPE_FLOAT){

            codeRaw("fmul");
        
        }else{//int

            codeRaw("imul");
            
        }
        
        storeVariable_jas(name);
    }

    void div_ass_j(char* name){
        loadVariable_jas(name);
        codeRaw("swap");
        if(findVariable(name)->type==OBJECT_TYPE_FLOAT){

            codeRaw("fdiv");
        
        }else{//int

            codeRaw("idiv");
            
        }
        
        storeVariable_jas(name);
    }

    void rem_ass_j(char* name){
        loadVariable_jas(name);
        codeRaw("swap");
        if(findVariable(name)->type==OBJECT_TYPE_FLOAT){

            codeRaw("frem");
        
        }else{//int

            codeRaw("irem");
            
        }
        
        storeVariable_jas(name);
    }

    void bor_ass_j(char* name){
        loadVariable_jas(name);
        codeRaw("swap");
        codeRaw("ior");
        
        storeVariable_jas(name);
    }

    void ban_ass_j(char* name){
        loadVariable_jas(name);
        codeRaw("swap");
        codeRaw("iand");
        
        storeVariable_jas(name);
    }

    void shl_ass_j(char* name){
        loadVariable_jas(name);
        codeRaw("swap");
        codeRaw("ishl");
        
        storeVariable_jas(name);
    }

    void shr_ass_j(char* name){
        loadVariable_jas(name);
        codeRaw("swap");
        codeRaw("ishr");
        
        storeVariable_jas(name);
    }

    


    void unary_jas(int op){
        switch(op){
            case OP_BNT:
                codeRaw("ldc -1");
                codeRaw("ixor");
                break;
            default:

                break;
        }
    }








    //load ident
    void loadVariable_jas(char* variableName) {
        Object* variable = NULL;
        for(int i = scopeLevel; i >=0;i--){
            struct node* now=scopeTable[i];

            while(now!=NULL){
                if(strcmp(now->obj->symbol->name, variableName)==0){
                    variable=now->obj;
                    break;
                }
                now=now->next;
            }
            if(variable!=NULL){
                break;
            }
        }
        //jasmin
        switch(variable->type) {
            case OBJECT_TYPE_INT :
                code("iload %ld",variable->symbol->addr+2);
                break;
            case OBJECT_TYPE_FLOAT :
                code("fload %ld",variable->symbol->addr+2);
                break;

            case OBJECT_TYPE_BOOL :
                code("iload %ld",variable->symbol->addr+2);
                break;
            
            case OBJECT_TYPE_STR :
                code("aload %ld",variable->symbol->addr+2);
                break;
            default:
                code("wtfload %ld",variable->symbol->addr+2);
                break;
        }

    }

    void storeVariable_jas(char* variableName) {
        Object* variable = NULL;
        for(int i = scopeLevel; i >=0;i--){
            struct node* now=scopeTable[i];

            while(now!=NULL){
                if(strcmp(now->obj->symbol->name, variableName)==0){
                    variable=now->obj;
                    break;
                }
                now=now->next;
            }
            if(variable!=NULL){
                break;
            }
        }
        //jasmin
        switch(variable->type) {
            case OBJECT_TYPE_INT :
                code("istore %ld",variable->symbol->addr+2);
                break;
            case OBJECT_TYPE_FLOAT :
                code("fstore %ld",variable->symbol->addr+2);
                break;

            case OBJECT_TYPE_BOOL :
                code("istore %ld",variable->symbol->addr+2);
                break;
            
            case OBJECT_TYPE_STR :
                code("astore %ld",variable->symbol->addr+2);
                break;
            default:
                code("wtfstore %ld",variable->symbol->addr+2);
                break;
        }

    }
