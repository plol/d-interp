module parser;

import std.file, std.format;

import std.stdio, std.conv, std.typecons, std.exception;
import std.algorithm, std.range, std.array, std.typetuple, std.regex;
import std.datetime;

import internal.typeinfo;
import internal.ast;
import stuff;
import lexer;

import parsergen;


Tok getTok(Token t) { return t.tok; }

Rule!Tok[] grammar = [
    rule!Tok("StmtList", "Stmt"),
    rule!Tok("StmtList", "StmtList", "Stmt"),

    //rule!Tok("Stmt", "Label"),
    rule!Tok("Stmt", Tok.semi),
    rule!Tok("Stmt", "Expr", Tok.semi),
    rule!Tok("Stmt", "Declaration"),
    rule!Tok("Stmt", "If"),
    rule!Tok("Stmt", "While"),
    //rule!Tok("Stmt", "DoWhile"),
    //rule!Tok("Stmt", "For"),
    rule!Tok("Stmt", "Foreach"),
    //rule!Tok("Stmt", "Switch"),
    //rule!Tok("Stmt", "Continue"),
    //rule!Tok("Stmt", "Break"),
    //rule!Tok("Stmt", "Return"),
    //rule!Tok("Stmt", "Goto"),
    //rule!Tok("Stmt", "With"),
    //rule!Tok("Stmt", "Synchronized"),
    //rule!Tok("Stmt", "Try"),
    //rule!Tok("Stmt", "ScopeGuard"),
    //rule!Tok("Stmt", "Throw"),
    //rule!Tok("Stmt", "Asm"),
    //rule!Tok("Stmt", "Pragma"),
    //rule!Tok("Stmt", "Mixin"),
    //rule!Tok("Stmt", "StaticCondition"),
    //rule!Tok("Stmt", "StaticAssert"),
    //rule!Tok("Stmt", "TemplateMixin"),
    //rule!Tok("Stmt", "Import"),
    rule!Tok("Stmt", "CurlStmtList"),

    //rule!Tok("Declaration", "Alias"),
    rule!Tok("Declaration", "Decl"),

    rule!Tok("Decl", "StorageClasses", "Decl"),
    rule!Tok("Decl", "Type", "ComIdList", Tok.semi),
    rule!Tok("Decl", "Type", Tok.id, "Parameters", "FunctionBody"),
    rule!Tok("Decl", "Type", Tok.id, "Parameters", "FunctionAttributes", "FunctionBody"),

    rule!Tok("FunctionBody", "CurlStmtList"),

    rule!Tok("StorageClasses", "StorageClass"),
    rule!Tok("StorageClasses", "StorageClasses", "StorageClass"),
    rule!Tok("StorageClasses", "StorageClass"),

    rule!Tok("FunctionAttributes", "FunctionAttribute"),
    rule!Tok("FunctionAttributes", "FunctionAttributes", "FunctionAttribute"),

    rule!Tok("StorageClass", Tok.abstract_),
    rule!Tok("StorageClass", Tok.auto_),
    rule!Tok("StorageClass", Tok.deprecated_),
    rule!Tok("StorageClass", Tok.enum_),
    rule!Tok("StorageClass", Tok.extern_),
    rule!Tok("StorageClass", Tok.final_),
    rule!Tok("StorageClass", Tok.override_),
    rule!Tok("StorageClass", Tok.t__gshared),
    rule!Tok("StorageClass", Tok.scope_),
    rule!Tok("StorageClass", Tok.static_),
    rule!Tok("StorageClass", Tok.synchronized_),
    rule!Tok("StorageClass", "MethodAttribute"),

    rule!Tok("MethodAttribute", Tok.inout_),
    rule!Tok("MethodAttribute", Tok.const_),
    rule!Tok("MethodAttribute", Tok.immutable_),
    rule!Tok("MethodAttribute", Tok.shared_),
    rule!Tok("MethodAttribute", "FunctionAttribute"),

    rule!Tok("FunctionAttribute", Tok.nothrow_),
    rule!Tok("FunctionAttribute", Tok.pure_),
    rule!Tok("FunctionAttribute", Tok.at, Tok.id),

    rule!Tok("ComIdList", Tok.id),
    rule!Tok("ComIdList", "ComIdList", Tok.comma, Tok.id),

    rule!Tok("While", Tok.while_, "ParExpr", "Stmt"),

    rule!Tok("Foreach", Tok.foreach_, Tok.lpar, "ForeachTypeList", Tok.semi,
                "Expr", Tok.rpar, "Stmt"),
    rule!Tok("Foreach", Tok.foreach_, Tok.lpar, "ForeachTypeList", Tok.semi,
                "Expr", Tok.dotdot, "Expr", Tok.rpar, "Stmt"),

    rule!Tok("If", Tok.if_, "ParExpr", "CurlStmtList"),
    rule!Tok("If", Tok.if_, "ParExpr", "CurlStmtList", Tok.else_, "CurlStmtList"),

    rule!Tok("ForeachTypeList", "ForeachType"),
    rule!Tok("ForeachTypeList", "ForeachTypeList", Tok.comma, "ForeachType"),

    rule!Tok("ForeachType", Tok.id),
    rule!Tok("ForeachType", Tok.ref_, Tok.id),
    rule!Tok("ForeachType", "Type", Tok.id),
    rule!Tok("ForeachType", Tok.ref_, "Type", Tok.id),

    rule!Tok("CurlStmtList", Tok.lcurl, "StmtList", Tok.rcurl),
    rule!Tok("CurlStmtList", Tok.lcurl, Tok.rcurl),

    rule!Tok("ParExpr", Tok.lpar, "Expr", Tok.rpar),

    rule!Tok("Expr", "AssignExpr"),
    rule!Tok("Expr", "Expr", Tok.comma, "AssignExpr"),

    rule!Tok("AssignExpr", "CondExpr"),
    rule!Tok("AssignExpr", "CondExpr", "OpSet", "AssignExpr"),
    rule!Tok("OpSet", Tok.set),
    rule!Tok("OpSet", Tok.div_set),
    rule!Tok("OpSet", Tok.and_set),
    rule!Tok("OpSet", Tok.or_set),
    rule!Tok("OpSet", Tok.sub_set),
    rule!Tok("OpSet", Tok.add_set),
    rule!Tok("OpSet", Tok.ltlt_set),
    rule!Tok("OpSet", Tok.gtgt_set),
    rule!Tok("OpSet", Tok.gtgtgt_set),
    rule!Tok("OpSet", Tok.star_set),
    rule!Tok("OpSet", Tok.perc_set),
    rule!Tok("OpSet", Tok.xor_set),
    rule!Tok("OpSet", Tok.pow_set),
    rule!Tok("OpSet", Tok.tilde_set),

    rule!Tok("CondExpr", "OrOrExpr"),
    rule!Tok("CondExpr", "OrOrExpr", Tok.question, "Expr", Tok.colon, "CondExpr"),

    rule!Tok("OrOrExpr", "AndAndExpr"),
    rule!Tok("OrOrExpr", "OrOrExpr", Tok.oror, "AndAndExpr"),
    
    rule!Tok("AndAndExpr", "OrExpr"),
    rule!Tok("AndAndExpr", "CmpExpr"),
    rule!Tok("AndAndExpr", "AndAndExpr", Tok.andand, "OrExpr"),
    rule!Tok("AndAndExpr", "AndAndExpr", Tok.andand, "CmpExpr"),

    rule!Tok("OrExpr", "XorExpr"),
    rule!Tok("OrExpr", "OrExpr", Tok.or, "XorExpr"),

    rule!Tok("XorExpr", "AndExpr"),
    rule!Tok("XorExpr", "XorExpr", Tok.xor, "AndExpr"),

    rule!Tok("AndExpr", "ShiftExpr"),
    rule!Tok("AndExpr", "ShiftExpr", Tok.and, "ShiftExpr"),

    rule!Tok("CmpExpr", "ShiftExpr"),
    rule!Tok("CmpExpr", "EqualExpr"),
    rule!Tok("CmpExpr", "IdentityExpr"),
    rule!Tok("CmpExpr", "RelExpr"),
    rule!Tok("CmpExpr", "InExpr"),

    rule!Tok("EqualExpr", "ShiftExpr", Tok.eq, "ShiftExpr"),
    rule!Tok("EqualExpr", "ShiftExpr", Tok.bangeq, "ShiftExpr"),

    rule!Tok("IdentityExpr", "ShiftExpr", Tok.is_, "ShiftExpr"),
    rule!Tok("IdentityExpr", "ShiftExpr", Tok.bangis, "ShiftExpr"),

    rule!Tok("RelExpr", "ShiftExpr", "RelOp", "ShiftExpr"),
    rule!Tok("RelOp", Tok.lt),
    rule!Tok("RelOp", Tok.lteq),
    rule!Tok("RelOp", Tok.gt),
    rule!Tok("RelOp", Tok.gteq),
    rule!Tok("RelOp", Tok.bangltgteq),
    rule!Tok("RelOp", Tok.bangltgt),
    rule!Tok("RelOp", Tok.ltgt),
    rule!Tok("RelOp", Tok.ltgteq),
    rule!Tok("RelOp", Tok.banggt),
    rule!Tok("RelOp", Tok.banggteq),
    rule!Tok("RelOp", Tok.banglt),
    rule!Tok("RelOp", Tok.banglteq),

    rule!Tok("InExpr", "ShiftExpr", Tok.in_, "ShiftExpr"),
    rule!Tok("InExpr", "ShiftExpr", Tok.bangin, "ShiftExpr"),

    rule!Tok("ShiftExpr", "AddExpr"),
    rule!Tok("ShiftExpr", "ShiftExpr", Tok.ltlt, "AddExpr"),
    rule!Tok("ShiftExpr", "ShiftExpr", Tok.gtgt, "AddExpr"),
    rule!Tok("ShiftExpr", "ShiftExpr", Tok.gtgtgt, "AddExpr"),

    rule!Tok("AddExpr", "MulExpr"),
    rule!Tok("AddExpr", "CatExpr"),
    rule!Tok("AddExpr", "AddExpr", Tok.add, "MulExpr"),
    rule!Tok("AddExpr", "AddExpr", Tok.sub, "MulExpr"),

    rule!Tok("CatExpr", "AddExpr", Tok.tilde, "MulExpr"),

    rule!Tok("MulExpr", "UnaryExpr"),
    rule!Tok("MulExpr", "MulExpr", Tok.star, "UnaryExpr"),
    rule!Tok("MulExpr", "MulExpr", Tok.div, "UnaryExpr"),
    rule!Tok("MulExpr", "MulExpr", Tok.perc, "UnaryExpr"),


    rule!Tok("UnaryExpr", "PowExpr"),
    rule!Tok("UnaryExpr", "NewExpr"),
    rule!Tok("UnaryExpr", "CastExpr"),
    rule!Tok("UnaryExpr", "Prefix", "UnaryExpr"),

    rule!Tok("PowExpr", "PostfixExpr"),
    rule!Tok("PowExpr", "PostfixExpr", Tok.pow, "PowExpr"),

    rule!Tok("NewExpr", Tok.new_, "Type"),
    rule!Tok("NewExpr", Tok.new_, "Type", "ArgList"),
    // rule!Tok("NewExpr", "AllocatorArguments", Tok.new_, "Type"),
    // rule!Tok("NewExpr", "AllocatorArguments", Tok.new_, "Type", "ArgList"),
    //rule!Tok("NewExpr", "NewAnonClassExpr"),

    rule!Tok("CastExpr", Tok.cast_, Tok.lpar, "Type", Tok.rpar, "UnaryExpr"),
    rule!Tok("CastExpr", Tok.cast_, Tok.lpar, "CastQual", Tok.rpar, "UnaryExpr"),
    rule!Tok("CastExpr", Tok.cast_, Tok.lpar, Tok.rpar, "UnaryExpr"),

    rule!Tok("CastQual", Tok.const_),
    rule!Tok("CastQual", Tok.const_, Tok.shared_),
    rule!Tok("CastQual", Tok.inout_),
    rule!Tok("CastQual", Tok.inout_, Tok.shared_),
    rule!Tok("CastQual", Tok.immutable_),
    rule!Tok("CastQual", Tok.shared_),
    rule!Tok("CastQual", Tok.shared_, Tok.const_),
    rule!Tok("CastQual", Tok.shared_, Tok.inout_),

    rule!Tok("Type", "BasicType"),
    rule!Tok("Type", "IdList"),
    rule!Tok("Type", Tok.dot, "IdList"),
    rule!Tok("Type", Tok.const_, Tok.lpar, "Type", Tok.rpar),
    rule!Tok("Type", Tok.immutable_, Tok.lpar, "Type", Tok.rpar),
    rule!Tok("Type", Tok.shared_, Tok.lpar, "Type", Tok.rpar),
    rule!Tok("Type", Tok.inout_, Tok.lpar, "Type", Tok.rpar),
    rule!Tok("Type", "LambdaType"),
    rule!Tok("Type", "Type", "TypeSuffix"),

    rule!Tok("TypeSuffix", Tok.star),
    rule!Tok("TypeSuffix", Tok.lbra, Tok.rbra),
    rule!Tok("TypeSuffix", Tok.lbra, "AssignExpr", Tok.rbra),
    rule!Tok("TypeSuffix", Tok.lbra, "Type", Tok.rbra),

    rule!Tok("LambdaType", "Type", Tok.delegate_, "Parameters"),
    rule!Tok("LambdaType", "Type", Tok.function_, "Parameters"),

    rule!Tok("Parameters", Tok.lpar, Tok.rpar),
    rule!Tok("Parameters", Tok.lpar, "ParameterList", Tok.rpar),

    rule!Tok("ParameterList", "Parameter"),
    rule!Tok("ParameterList", "Parameter", Tok.comma, "ParameterList"),

    rule!Tok("Parameter", "Type"),
    rule!Tok("Parameter", "Type", Tok.id),
    
    rule!Tok("BasicType", Tok.bool_),
    rule!Tok("BasicType", Tok.char_),
    rule!Tok("BasicType", Tok.wchar_),
    rule!Tok("BasicType", Tok.dchar_),
    rule!Tok("BasicType", Tok.byte_),
    rule!Tok("BasicType", Tok.ubyte_),
    rule!Tok("BasicType", Tok.short_),
    rule!Tok("BasicType", Tok.ushort_),
    rule!Tok("BasicType", Tok.int_),
    rule!Tok("BasicType", Tok.uint_),
    rule!Tok("BasicType", Tok.long_),
    rule!Tok("BasicType", Tok.ulong_),
    rule!Tok("BasicType", Tok.float_),
    rule!Tok("BasicType", Tok.double_),
    rule!Tok("BasicType", Tok.real_),
    rule!Tok("BasicType", Tok.void_),

    rule!Tok("IdList", Tok.id),
    rule!Tok("IdList", "IdList", Tok.dot, Tok.id),

    rule!Tok("PostfixExpr", "PrimaryExpr"),
    rule!Tok("PostfixExpr", "PostfixExpr", Tok.dot, Tok.id),
    //rule!Tok("PostfixExpr", Tok.dot, "TemplateInstance"),
    rule!Tok("PostfixExpr", Tok.dot, "NewExpr"),
    rule!Tok("PostfixExpr", "PostfixExpr", "Postfix"),
    rule!Tok("PostfixExpr", "PostfixExpr", "ArgList"),
    rule!Tok("PostfixExpr", "PostfixExpr", "Slice"),
    rule!Tok("PostfixExpr", "PostfixExpr", "Index"),

    rule!Tok("PrimaryExpr", Tok.id),
    rule!Tok("PrimaryExpr", Tok.dot, Tok.id),
    //rule!Tok("PrimaryExpr", "TemplateInstance"),
    //rule!Tok("PrimaryExpr", Tok.dot, "TemplateInstance"),
    rule!Tok("PrimaryExpr", Tok.this_),
    rule!Tok("PrimaryExpr", Tok.super_),
    rule!Tok("PrimaryExpr", Tok.null_),
    rule!Tok("PrimaryExpr", Tok.true_),
    rule!Tok("PrimaryExpr", Tok.false_),
    rule!Tok("PrimaryExpr", Tok.dollar),
    rule!Tok("PrimaryExpr", Tok.t__FILE__),
    rule!Tok("PrimaryExpr", Tok.t__LINE__),
    rule!Tok("PrimaryExpr", Tok.num),
    rule!Tok("PrimaryExpr", Tok.char_lit),
    rule!Tok("PrimaryExpr", Tok.string_),
    //rule!Tok("PrimaryExpr", "ArrayLiteral"),
    //rule!Tok("PrimaryExpr", "AssocArrayLiteral"),
    //rule!Tok("PrimaryExpr", "Lambda"),
    //rule!Tok("PrimaryExpr", "FunctionLiteral"),
    //rule!Tok("PrimaryExpr", "AssertExpr"),
    //rule!Tok("PrimaryExpr", "MixinExpr"),
    //rule!Tok("PrimaryExpr", "ImportExpr"),
    //rule!Tok("PrimaryExpr", "BasicType", Tok.dot, Tok.id),
    //rule!Tok("PrimaryExpr", "TypeofExpr"),
    //rule!Tok("PrimaryExpr", "TypeidExpr"),
    //rule!Tok("PrimaryExpr", "IsExpr"),
    rule!Tok("PrimaryExpr", "ParExpr"),
    //rule!Tok("PrimaryExpr", "TraitsExpr"),


    rule!Tok("Prefix", Tok.addadd),
    rule!Tok("Prefix", Tok.subsub),
    rule!Tok("Prefix", Tok.add),
    rule!Tok("Prefix", Tok.and),
    rule!Tok("Prefix", Tok.star),
    rule!Tok("Prefix", Tok.sub),
    rule!Tok("Prefix", Tok.tilde),
    rule!Tok("Prefix", Tok.bang),

    rule!Tok("Postfix", Tok.addadd),
    rule!Tok("Postfix", Tok.subsub),

    rule!Tok("Slice", Tok.lbra, Tok.rbra),
    rule!Tok("Slice", Tok.lbra, "AssignExpr", Tok.dotdot, "AssignExpr", Tok.rbra),

    rule!Tok("ArgList", Tok.lpar, Tok.rpar),
    rule!Tok("ArgList", Tok.lpar, "ComExprList", Tok.rpar),

    rule!Tok("Index", Tok.lbra, "ComExprList", Tok.rbra),

    rule!Tok("ComExprList", "AssignExpr"),
    rule!Tok("ComExprList", "ComExprList", Tok.comma),
    rule!Tok("ComExprList", "ComExprList", Tok.comma, "AssignExpr"),

    ];

alias ParserGen!(Token, Ast, Tok, getTok, grammar, "Stmt", Tok.eof) P;

Ast defaultReduction1(P.StackItem a) {
    return a.terminal
        ? ast(a.token)
        : a.result;
}
Ast delegate(P.StackItem[])[string] reduction_table;

static this() {
    reduction_table["default_reduction"] = (P.StackItem[] ts) {
        return ts.length == 1
            ? defaultReduction1(ts[0])
            : ast(Ast.Type.sequence, ts.map!defaultReduction1().array());
    };

    reduction_table["StmtList"] = (P.StackItem[] ts) {
        if (ts.length == 2) {
            ts[0].result.sequence ~= ts[1].result;
            return ts[0].result;
        }
        return ast(Ast.Type.sequence, [ts[0].result]);
    };
    reduction_table["Stmt"] = (P.StackItem[] ts) {
        if (ts.length == 1 && ts[0].terminal) {
            return ast(Ast.Type.nothing, ts[0].token.loc);
        } else if (ts.length == 1) {
            return ts[0].result;
        } else if (ts.length == 2) {
            return ast(Ast.Type.statement, ts[0].result);
        }
        assert (0);
    };
    reduction_table["While"] = (P.StackItem[] ts) {
        return ast(Ast.Type.while_, ts[0].token.loc, ts[1].result, ts[2].result);
    };
    reduction_table["CurlStmtList"] = (P.StackItem[] ts) {
        if (ts.length == 2) {
            return ast(Ast.Type.sequence, ts[0].token.loc, cast(Ast[])[]);
        }  else {
            return ts[1].result;
        }
    };
    reduction_table["ParExpr"] = (P.StackItem[] ts) {
        return ts[1].result;
    };
    reduction_table["PrimaryExpr"] = (P.StackItem[] ts) {
        if (!ts[0].terminal) {
            return ts[0].result;
        }
        return ast(ts[0].token);
    };


    reduction_table["Expr"] = delegate (P.StackItem[] ts) {
        if (ts.length == 1) {
            return ts[0].result;
        }
        if (ts[0].result.type == Ast.Type.sequence) {
            ts[0].result.sequence ~= ts[2].result;
            return ts[0].result;
        } else {
            return ast(Ast.Type.sequence, ts[0].result.loc, [ts[0].result, ts[2].result]);
        }
    };
    reduction_table["AssignExpr"] = delegate (P.StackItem[] ts) {
        if (ts.length == 1) {
            return ts[0].result;
        }
        auto opstr = ts[1].terminal ? ts[1].token.str : ts[1].result.str;
        assert (opstr.endsWith("="));
        opstr.popBack();
        if (opstr.empty) {
            return ast(Ast.Type.assignment, ts[0].result.loc,
                    ts[0].result, ts[2].result);
        } else {
            return ast(Ast.Type.op_assignment, ts[0].result.loc,
                    opstr, ts[0].result, ts[2].result);
        }
    };

    auto reduce_binop = delegate (P.StackItem[] ts) {
        if (ts.length == 1) {
            return ts[0].result;
        }
        return ast(Ast.Type.binop, ts[0].result.loc,
                ts[1].terminal ? ts[1].token.str : ts[1].result.str,
                ts[0].result, ts[2].result);
    };

    reduction_table["OrOrExpr"] = reduce_binop;
    reduction_table["AndAndExpr"] = reduce_binop;
    reduction_table["OrExpr"] = reduce_binop;
    reduction_table["XorExpr"] = reduce_binop;
    reduction_table["AndExpr"] = reduce_binop;
    reduction_table["EqualExpr"] = reduce_binop;
    reduction_table["IdentityExpr"] = reduce_binop;
    reduction_table["RelExpr"] = reduce_binop;
    reduction_table["InExpr"] = reduce_binop;
    reduction_table["ShiftExpr"] = reduce_binop;
    reduction_table["AddExpr"] = reduce_binop;
    reduction_table["CatExpr"] = reduce_binop;
    reduction_table["MulExpr"] = reduce_binop;
    reduction_table["PowExpr"] = reduce_binop;
    reduction_table["PostfixExpr"] = (P.StackItem[] ts) {
        if (ts.length == 1) {
            return ts[0].result;
        }
        if (ts.length == 3) {
            return ast(Ast.Type.member_lookup, ts[0].result.loc,
                    ts[0].result, ts[2].token.str);
        }
        return ast(Ast.Type.postfix, ts[0].result.loc,
                ts[0].result, ts[1].result);
    };
    reduction_table["CondExpr"] = (P.StackItem[] ts) {
        if (ts.length == 1) {
            return ts[0].result;
        }
        return ast(Ast.Type.condexpr, ts[0].result.loc,
                ts[0].result, ts[2].result, ts[4].result);
    };
    reduction_table["UnaryExpr"] = (P.StackItem[] ts) {
        if (ts.length == 1) {
            return ts[0].result;
        }
        return ast(Ast.Type.prefix, ts[0].result.loc,
                ts[0].result, ts[1].result);
    };

    reduction_table["Type"] = (P.StackItem[] ts) {
        if (ts.length == 1) {
            return ast(Ast.Type.type, ts[0].result);
        }
        if (ts[0].terminal) {
            if (ts[0].token.tok == Tok.dot) {
                return ast(Ast.Type.module_lookup, ts[0].token.loc, ts[1].result);
            } else {
                return ast(Ast.Type.type, ts[0].token.loc,
                        get_typemod_type(ts[0].token.tok),
                        ts[2].result);
            }
        } else if (ts[1].result.type == Ast.Type.type_mod) {
            return ast(Ast.Type.type, ts[0].result.loc,
                    ts[1].result.type_mod, ts[0].result);
        } else {
            assert (0);
        }
    };
    reduction_table["TypeSuffix"] = (P.StackItem[] ts) {
        if (ts[0].token.tok == Tok.star) {
            return ast(Ast.Type.type_mod, TypeMod.Type.pointer);
        } else if (ts[0].token.tok == Tok.lbra) {
            if (ts.length == 2) {
                return ast(Ast.Type.type_mod, TypeMod.Type.array);
            } else if (ts.length == 3) {
                return ast(Ast.Type.type_mod, TypeMod.Type.slicy, ts[1].result);
            } else {
                assert (0);
            }
        } else {
            assert (0);
        }
    };
    reduction_table["BasicType"] = (P.StackItem[] ts) {
        return ast(Ast.Type.basic_type, ts[0].token.loc,
                ti_type_from_tok(ts[0].token.tok));
    };
    reduction_table["CastExpr"] = (P.StackItem[] ts) {
        if (ts.length == 4) {
            return ast(Ast.Type.cast_, ts[0].token.loc, ts[3].result);
        } else if (ts.length == 5) {
            return ast(Ast.Type.cast_, ts[0].token.loc,
                    ts[2].result, ts[4].result);
        } else {
            assert (0);
        }
    };
    reduction_table["CastQual"] = (P.StackItem[] ts) {
        Ast ret = ast(Ast.Type.nothing);
        foreach (t; ts) {
            ret = ast(Ast.Type.type, t.token.loc,
                    get_typemod_type(t.token.tok),
                    ret);
        }
        return ret;
    };

    reduction_table["ComIdList"] = (P.StackItem[] ts) {
        if (ts.length == 1) {
            return ast(Ast.Type.id_list, ts[0].token.loc, [ts[0].token]);
        } else {
            ts[0].result.id_list ~= ts[2].token;
            return ts[0].result;
        }
    };

    reduction_table["Decl"] = (P.StackItem[] ts) {
        if (ts.length == 2) {
            assert (0);
    //rule!Tok("Decl", "StorageClasses", "Decl"),
        } else if (ts[1].terminal) {
            assert (0);
    //rule!Tok("Decl", "Type", Tok.id, "Parameters", "FunctionBody"),
    //rule!Tok("Decl", "Type", Tok.id, "Parameters", "FunctionAttributes", "FunctionBody"),
        } else {
            return ast(Ast.Type.vardecl, ts[1].result.loc,
                    ts[0].result, ts[1].result);
        }
    };
}


TypeMod.Type get_typemod_type(Tok tok) {
    switch (tok) {
        default: assert (0);
        case Tok.const_: return TypeMod.Type.const_;
        case Tok.immutable_: return TypeMod.Type.immutable_;
        case Tok.inout_: return TypeMod.Type.inout_;
        case Tok.shared_: return TypeMod.Type.shared_;
    }
}

TI.Type ti_type_from_tok(Tok tok) {
    switch (tok) {
        default: assert (0);
        case Tok.bool_:   return TI.Type.bool_;
        case Tok.char_:   return TI.Type.char_;
        case Tok.wchar_:  return TI.Type.wchar_;
        case Tok.dchar_:  return TI.Type.dchar_;
        case Tok.byte_:   return TI.Type.byte_;
        case Tok.ubyte_:  return TI.Type.ubyte_;
        case Tok.short_:  return TI.Type.short_;
        case Tok.ushort_: return TI.Type.ushort_;
        case Tok.int_:    return TI.Type.int_;
        case Tok.uint_:   return TI.Type.uint_;
        case Tok.long_:   return TI.Type.long_;
        case Tok.ulong_:  return TI.Type.ulong_;
        case Tok.float_:  return TI.Type.float_;
        case Tok.double_: return TI.Type.double_;
        case Tok.real_:   return TI.Type.real_;
        case Tok.void_:   return TI.Type.void_;
    }
}

