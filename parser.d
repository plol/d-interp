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


enum Rule[] grammar = [
    rule("S", "StmtList"),

    rule("StmtList", "Stmt"),
    rule("StmtList", "StmtList", "Stmt"),

    rule("Stmt", "While"),
    rule("Stmt", "Foreach"),
    rule("Stmt", "If"),
    rule("Stmt", "Expr", Tok.semi),
    rule("Stmt", "CurlStmtList"),

    rule("While", Tok.while_, "ParExpr", "CurlStmtList"),

    rule("Foreach", Tok.foreach_, Tok.lpar, "ForeachTypeList", Tok.semi,
            "Expr", Tok.rpar, "CurlStmtList"),
    rule("Foreach", Tok.foreach_, Tok.lpar, "ForeachTypeList", Tok.semi,
            "Expr", Tok.dotdot, "Expr", Tok.rpar, "CurlStmtList"),

    rule("If", Tok.if_, "ParExpr", "CurlStmtList"),
    rule("If", Tok.if_, "ParExpr", "CurlStmtList", Tok.else_, "CurlStmtList"),

    rule("ForeachTypeList", "ForeachType"),
    rule("ForeachTypeList", "ForeachTypeList", Tok.comma, "ForeachType"),

    rule("ForeachType", Tok.id),
    rule("ForeachType", Tok.ref_, Tok.id),

    rule("CurlStmtList", Tok.lcurl, "StmtList", Tok.rcurl),
    rule("CurlStmtList", Tok.lcurl, Tok.rcurl),

    rule("Expr", "CommaExpr"),
    rule("CommaExpr", "AssignExpr"),
    rule("CommaExpr", "CommaExpr", Tok.comma, "AssignExpr"),
    rule("AssignExpr", "CondExpr"),
    rule("AssignExpr", "CondExpr", "OpSet", "AssignExpr"),

    rule("CondExpr", "OpExpr"),
    rule("CondExpr", "OpExpr", Tok.question, "Expr", Tok.colon, "CondExpr"),

    rule("OpExpr", "PrimaryExpr"),
    rule("OpExpr", "Prefix", "OpExpr"),
    rule("OpExpr", "OpExpr", "Postfix"),
    rule("OpExpr", "OpExpr", "BinOp", "OpExpr"),

    rule("PrimaryExpr", "ParExpr"),
    rule("PrimaryExpr", "PrimaryExprT"),
    rule("PrimaryExprT", Tok.id),
    rule("PrimaryExprT", Tok.num),
    rule("PrimaryExprT", Tok.string_),

    rule("ParExpr", Tok.lpar, "Expr", Tok.rpar),

    rule("Prefix", Tok.addadd),
    rule("Prefix", Tok.subsub),
    rule("Prefix", Tok.add),
    rule("Prefix", Tok.sub),
    rule("Prefix", Tok.tilde),
    rule("Prefix", Tok.bang),

    rule("Postfix", Tok.addadd),
    rule("Postfix", Tok.subsub),
    rule("Postfix", "ArgList"),
    rule("Postfix", "Index"),
    rule("Postfix", "Slice"),

    rule("ArgList", Tok.lpar, Tok.rpar),
    rule("ArgList", Tok.lpar, "ComExprList", Tok.rpar),

    rule("Index", Tok.lbra, "ComExprList", Tok.rbra),
    rule("Slice", Tok.lbra, Tok.rbra),
    rule("Slice", Tok.lbra, "AssignExpr", Tok.dotdot, "AssignExpr"),

    rule("ComExprList", "AssignExpr"),
    rule("ComExprList", "ComExprList", Tok.comma, "AssignExpr"),

    rule("OpSet", Tok.set),
    rule("OpSet", Tok.op_set),

    rule("BinOp", Tok.add),
    rule("BinOp", Tok.and),
    rule("BinOp", Tok.star),
    rule("BinOp", Tok.sub),
    rule("BinOp", Tok.tilde),
    rule("BinOp", Tok.bin_op),
    ];

void main() {

    string delegate(StackItem[])[string] reduction_table;


    string delegate(StackItem) sif =
        a => a.terminal ? "'" ~ a.token.str ~ "'" : a.result;
    string delegate(StackItem[]) rf =
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
    auto p = parsergen.Parser(grammar, "S", Tok.eof, reduction_table);
    sw.stop();
    writeln("TOOK ", sw.peek().hnsecs / 10_000.0, " ms!",
           " (", p.states.length, ")");

    auto f = File("states.txt", "w");
    foreach (i, state; p.states) {
        f.writeln("state ", i, ":\n", state);
    }

    auto input = "
        1 > 2 ? x : y += 2 > 1 ? y : 1 > 2 ? x : x;
    ";

    foreach (tok; Lexer(input)) {
        p.feed(tok);
    }
    p.feed(Token(-1, "", Tok.eof));
    writeln(p.result.result);
}

