module parser;

import std.file, std.format;

import std.stdio, std.conv, std.typecons, std.exception;
import std.algorithm, std.range, std.array, std.typetuple, std.regex;
import std.datetime;

import stuff;
import lexer;

import parsergen;

//Sym[][] gram = [
//    [Sym("S"), Sym("A"), Sym("B")],
//    [Sym("A"), Sym(Tok.a), Sym("A"), Sym(Tok.b)],
//    [Sym("A"), Sym(Tok.a)],
//    [Sym("B"), Sym(Tok.d)],
//    ];
//
//Sym[][] grammar2 = [
//    [Sym("S"), Sym("A")],
//    [Sym("S"), Sym("C")],
//    [Sym("A"), Sym("B"), Sym(Tok.a)],
//    [Sym("C"), Sym("B"), Sym(Tok.c)],
//    [Sym("B"), Sym("D"), Sym(Tok.b)],
//    [Sym("D"), Sym(Tok.d)],
//    ];
//
//Sym[][] grammar3 = [
//    [Sym("S"), Sym(Tok.a)],
//    [Sym("S"), Sym("S"), Sym(Tok.a)],
//    ];

Tok getTok(Token t) { return t.tok; }


Rule!Tok[] grammar = [
    rule!Tok("S", "StmtList"),

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

alias ParserGen!(Token, string, Tok, getTok, grammar, "S", Tok.eof) P;

void main() {

    string delegate(P.StackItem[])[string] reduction_table;


    string delegate(P.StackItem) sif =
        a => a.terminal ? "'" ~ a.token.str ~ "'" : a.result;
    string delegate(P.StackItem[]) rf =
        ts => ts.length == 1 ? sif(ts[0]) : "(" ~ ts.map!sif.join(" ") ~ ")";

    reduction_table["S"]            = rf;
    reduction_table["StmtList"]     = rf;
    reduction_table["Stmt"]         = rf;
    reduction_table["While"]        = rf;
    reduction_table["Foreach"]        = rf;
    reduction_table["If"]        = rf;
    reduction_table["ForeachTypeList"]        = rf;
    reduction_table["ForeachType"]        = rf;
    reduction_table["CurlStmtList"]        = rf;
    reduction_table["Expr"]        = rf;
    reduction_table["CommaExpr"] = rf;
    reduction_table["AssignExpr"] = rf;
    reduction_table["CondExpr"] = rf;
    reduction_table["OpExpr"] = rf;
    reduction_table["PrimaryExpr"] = rf;
    reduction_table["PrimaryExprT"] = rf;
    reduction_table["ParExpr"] = rf;
    reduction_table["Prefix"] = rf;
    reduction_table["Postfix"] = rf;
    reduction_table["ArgList"] = rf;
    reduction_table["Index"] = rf;
    reduction_table["Slice"] = rf;
    reduction_table["ComExprList"] = rf;
    reduction_table["OpSet"] = rf;
    reduction_table["BinOp"] = rf;

    writeln("HI");
    auto sw = StopWatch();
    sw.start();
    auto p = P.Parser(reduction_table);
    sw.stop();
    writeln("TOOK ", sw.peek().hnsecs / 10_000.0, " ms!",
           " (", p.states.length, ")");

    auto f = File("states.txt", "w");
    foreach (i, state; p.states) {
        f.writeln("state ", i, ":\n", state);
    }

    auto input = "
        1;
    ";

    foreach (tok; Lexer(input)) {
        p.feed(tok);
    }
    p.feed(Token(-1, "", Tok.eof));
    writeln(p.result.result);
}

