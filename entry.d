module entry;

import std.stdio, std.range, std.array;

import internal.ir, internal.env, internal.val;
import internal.typeinfo, internal.ctenv, internal.typecheck;
import internal.ast2ir, internal.bytecode, internal.bcgen;
import internal.interp;

import lexer, parser;



void print_throwable(Throwable t) {
    writefln("%s@%s(%s): %s", t.classinfo.name, t.file, t.line, t.msg);
    bool lulz;
    ulong x;
    foreach (i, s; t.info) {
        if (i < 6) {
            writeln(s);
        } else {
            lulz = true;
            x = i;
        }
    }
    if (lulz) {
        writefln("... (%s rows total)", x);
    }
}

void run_code(ref P.Parser p, CTEnv ct_env, string file, string input) {
    auto lx = Lexer(input, file);

    if (lx.empty) return;

    //writeln(lx);

    foreach (tok; lx) {
        p.feed(tok);
    }
    p.feed(Token(Loc(-1, ""), Tok.eof, ""));
    if (p.results.empty) {
        return;
    }
    writeln("parsed");
//    writefln("%(%s\n%)", p.results);

    Val val;

    foreach (r; p.results) {
        auto ir = toIR(r, ct_env);

        try {
            resolve(ir, ct_env);
        } catch (SemanticFault f) {
            writeln("error ", r.loc, ": ", f.msg);
            break;
        }

        auto env = ct_env.get_runtime_env();
        
        try {
            val = execute(ir, ct_env, env);
        } catch (Throwable t) {
            print_throwable(t);
            break;
        }

        if (ir.ti.type != TI.Type.void_) {
            writeln(val.toString(ir.ti));
        }
        ct_env.assimilate(env);
    }
    p.results = [];
}

Val execute(IR ir, CTEnv ct_env) {
    auto env = ct_env.get_runtime_env();
    return execute(ir, ct_env, env);
}

Val execute(IR ir, CTEnv ct_env, Env env) {
    ByteCode[] bc = ir.generate_bytecode(ct_env);
    return bc.interpret(env);
}

