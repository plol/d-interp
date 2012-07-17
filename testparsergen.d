import std.conv, std.stdio, std.algorithm, std.range;

import parsergen;


enum Tok { a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,y,z,eof }

Rule!Tok[] grammar = [
    rule!Tok("S", "E", Tok.z),
    rule!Tok("E", "C"),
    rule!Tok("E", "C", Tok.s, "E"),
    rule!Tok("C", "P"),
    rule!Tok("C", "C", Tok.p, "P"),
    rule!Tok("P", Tok.i),
    rule!Tok("P", Tok.a),
    ];

Tok getTok(Tok t) { return t; }

alias ParserGen!(Tok, string, Tok, getTok, grammar, "S", Tok.eof) P;

void main() {

    string delegate(P.StackItem[])[string] reduction_table;
    reduction_table["default_reduction"] = (P.StackItem[] ts) {
        return "("
            ~map!"a.terminal ? to!string(a.token) : a.result"(ts).join(" ")
            ~")";
    };

    auto p = P.make_parser(reduction_table);

    foreach (i, ref state; p.states) {
        writefln("state %s:\n%s", i, state);
    }

    foreach (tok; [Tok.a, Tok.s, Tok.a, Tok.p, Tok.i, Tok.z]) {
        p.feed(tok);
    }
    p.feed(Tok.eof);
    writeln(p.results);
}
