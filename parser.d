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

    rule!Tok("Expr", "CommaExpr"),
    rule!Tok("CommaExpr", "AssignExpr"),
    rule!Tok("CommaExpr", "CommaExpr", Tok.comma, "AssignExpr"),
    rule!Tok("AssignExpr", "CondExpr"),
    rule!Tok("AssignExpr", "CondExpr", "OpSet", "AssignExpr"),

    rule!Tok("CondExpr", "OpExpr"),
    rule!Tok("CondExpr", "OpExpr", Tok.question, "Expr", Tok.colon, "CondExpr"),

    rule!Tok("OpExpr", "PrimaryExpr"),
    rule!Tok("OpExpr", "Prefix", "OpExpr"),
    rule!Tok("OpExpr", "OpExpr", "Postfix"),
    rule!Tok("OpExpr", "OpExpr", "BinOp", "OpExpr"),

    rule!Tok("PrimaryExpr", "ParExpr"),
    rule!Tok("PrimaryExpr", Tok.id),
    rule!Tok("PrimaryExpr", Tok.num),
    rule!Tok("PrimaryExpr", Tok.string_),

    rule!Tok("ParExpr", Tok.lpar, "Expr", Tok.rpar),

    rule!Tok("Prefix", Tok.addadd),
    rule!Tok("Prefix", Tok.subsub),
    rule!Tok("Prefix", Tok.add),
    rule!Tok("Prefix", Tok.sub),
    rule!Tok("Prefix", Tok.tilde),
    rule!Tok("Prefix", Tok.bang),

    rule!Tok("Postfix", Tok.addadd),
    rule!Tok("Postfix", Tok.subsub),
    rule!Tok("Postfix", "ArgList"),
    rule!Tok("Postfix", "Index"),
    rule!Tok("Postfix", "Slice"),

    rule!Tok("ArgList", Tok.lpar, Tok.rpar),
    rule!Tok("ArgList", Tok.lpar, "ComExprList", Tok.rpar),

    rule!Tok("Index", Tok.lbra, "ComExprList", Tok.rbra),
    rule!Tok("Slice", Tok.lbra, Tok.rbra),
    rule!Tok("Slice", Tok.lbra, "AssignExpr", Tok.dotdot, "AssignExpr"),

    rule!Tok("ComExprList", "AssignExpr"),
    rule!Tok("ComExprList", "ComExprList", Tok.comma, "AssignExpr"),

    rule!Tok("OpSet", Tok.set),
    rule!Tok("OpSet", Tok.op_set),

    rule!Tok("BinOp", Tok.add),
    rule!Tok("BinOp", Tok.and),
    rule!Tok("BinOp", Tok.star),
    rule!Tok("BinOp", Tok.sub),
    rule!Tok("BinOp", Tok.tilde),
    rule!Tok("BinOp", Tok.bin_op),
    ];

alias ParserGen!(Token, Ast, Tok, getTok, grammar, "Stmt", Tok.eof) P;

Ast siff(P.StackItem a) {
    return a.terminal
        ? ast(a.token)
        : a.result;
}
Ast delegate(P.StackItem[])[string] reduction_table;

static this() {
    reduction_table["default_reduction"] = (P.StackItem[] ts) {
        return ts.length == 1
            ? siff(ts[0])
            : ast(Ast.Type.sequence, ts.map!siff().array());
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
    reduction_table["AssignExpr"] = (P.StackItem[] ts) {
        if (ts.length == 1) {
            return ts[0].result;
        }
        assert (ts.length == 3);
        writeln("assuming assignexpr to be = not += etc");
        return ast(Ast.Type.assignment, ts[0].result, ts[2].result);
    };
    reduction_table["OpExpr"] = (P.StackItem[] ts) {
        if (ts.length == 1) {
            return ts[0].result;
        }
        assert (ts.length == 3);
        return ast(Ast.Type.binop, ts[0].result, ts[1].result, ts[2].result);
    };
}

