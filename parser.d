module parser;

import std.file, std.format;

import std.stdio, std.conv, std.typecons, std.exception;
import std.algorithm, std.range, std.array, std.typetuple, std.regex;
import std.datetime;

import internal.ast;
import stuff;
import lexer;

import parsergen;


Tok getTok(Token t) { return t.tok; }

Rule!Tok[] grammar = [
    rule!Tok("StmtList", "Stmt"),
    rule!Tok("StmtList", "StmtList", "Stmt"),

    rule!Tok("Stmt", "While"),
    rule!Tok("Stmt", "Foreach"),
    rule!Tok("Stmt", "If"),
    rule!Tok("Stmt", "Expr", Tok.semi),
    rule!Tok("Stmt", "CurlStmtList"),

    rule!Tok("While", Tok.while_, "ParExpr", "CurlStmtList"),

    rule!Tok("Foreach", Tok.foreach_, Tok.lpar, "ForeachTypeList", Tok.semi,
                "Expr", Tok.rpar, "CurlStmtList"),
    rule!Tok("Foreach", Tok.foreach_, Tok.lpar, "ForeachTypeList", Tok.semi,
                "Expr", Tok.dotdot, "Expr", Tok.rpar, "CurlStmtList"),

    rule!Tok("If", Tok.if_, "ParExpr", "CurlStmtList"),
    rule!Tok("If", Tok.if_, "ParExpr", "CurlStmtList", Tok.else_, "CurlStmtList"),

    rule!Tok("ForeachTypeList", "ForeachType"),
    rule!Tok("ForeachTypeList", "ForeachTypeList", Tok.comma, "ForeachType"),

    rule!Tok("ForeachType", Tok.id),
    rule!Tok("ForeachType", Tok.ref_, Tok.id),

    rule!Tok("CurlStmtList", Tok.lcurl, "StmtList", Tok.rcurl),
    rule!Tok("CurlStmtList", Tok.lcurl, Tok.rcurl),

    rule!Tok("ParExpr", Tok.lpar, "Expr", Tok.rpar),

    rule!Tok("Expr", "AssignExpr"),
    rule!Tok("Expr", "Expr", Tok.comma, "AssignExpr"),
    rule!Tok("AssignExpr", "CondExpr"),
    rule!Tok("AssignExpr", "CondExpr", "OpSet", "AssignExpr"),

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
    //rule!Tok("UnaryExpr", "NewExpr"),
    //rule!Tok("UnaryExpr", "CastExpr"),
    rule!Tok("UnaryExpr", "Prefix", "UnaryExpr"),

    rule!Tok("PowExpr", "PostfixExpr"),
    rule!Tok("PowExpr", "PowExpr", Tok.pow, "PostfixExpr"),

    rule!Tok("PostfixExpr", "PrimaryExpr"),
    rule!Tok("PostfixExpr", "PostfixExpr", Tok.dot, Tok.id),
    //rule!Tok("PostfixExpr", Tok.dot, "TemplateInstance"),
    //rule!Tok("PostfixExpr", Tok.dot, "NewExpr"),
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

    rule!Tok("ArgList", Tok.lpar, Tok.rpar),
    rule!Tok("ArgList", Tok.lpar, "ComExprList", Tok.rpar),

    rule!Tok("Index", Tok.lbra, "ComExprList", Tok.rbra),

    rule!Tok("Slice", Tok.lbra, Tok.rbra),
    rule!Tok("Slice", Tok.lbra, "AssignExpr", Tok.dotdot, "AssignExpr", Tok.rbra),

    rule!Tok("ComExprList", "AssignExpr"),
    rule!Tok("ComExprList", "ComExprList", Tok.comma, "AssignExpr"),

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
        if (ts.length == 2) {
            return ast(Ast.Type.statement, ts[0].result);
        }
        return ts[0].result;
    };
    reduction_table["While"] = (P.StackItem[] ts) {
        return ast(Ast.Type.while_, ts[1].result, ts[2].result);
    };
    reduction_table["CurlStmtList"] = (P.StackItem[] ts) {
        if (ts.length == 3) {
            return ts[1].result;
        } else {
            assert (0);
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

    auto reduce_binop = delegate (P.StackItem[] ts) {
        if (ts.length == 1) {
            return ts[0].result;
        }
        return ast(Ast.Type.binop,
                ts[1].terminal ? ts[1].token.str : ts[1].result.str,
                ts[0].result, ts[2].result);
    };

    reduction_table["Expr"] = reduce_binop; //comma
    reduction_table["AssignExpr"] = reduce_binop;
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
            return ast(Ast.Type.member_lookup, ts[0].result, ts[2].token.str);
        }
        return ast(Ast.Type.postfix, ts[0].result, ts[1].result);
    };
    //reduction_table["CondExpr"] = 
    reduction_table["UnaryExpr"] = (P.StackItem[] ts) {
        if (ts.length == 1) {
            return ts[0].result;
        }
        return ast(Ast.Type.prefix, ts[1].result, ts[1].result);
    };
}

