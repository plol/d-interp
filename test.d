import std.stdio, std.traits, std.conv;

import std.datetime, std.array;

import internal.ir, internal.env, internal.interp, internal.val;
import internal.typeinfo, internal.ctenv, internal.typecheck;

import lexer, parser;

//        declare(int_int_bool_delegate, "$lt_int", Val((Val[] vars) {
//                    return Val(vars[0].int_val < vars[1].int_val);
//                    }));
//        auto int_type = new TI;
//        int_type.type = TI.Type.int_;
//        auto bool_type = new TI;
//        int_type.type = TI.Type.bool_;
//
//        auto int_int_int_delegate = new TI;
//        int_int_int_delegate.type = TI.Type.builtin_delegate;
//        int_int_int_delegate.ti1 = int_type;
//        int_int_int_delegate.tis = [int_type, int_type];
//
//        auto int_int_bool_delegate = new TI;
//        int_int_bool_delegate.type = TI.Type.builtin_delegate;
//        int_int_bool_delegate.ti1 = bool_type;
//        int_int_bool_delegate.tis = [int_type, int_type];

int add_int(int a, int b) {
    return a + b;
}
bool lt_int(int a, int b) {
    return a < b;
}
bool cast_int_bool(int a) {
    return cast(bool)a;
}
bool not(bool b) {
    return !b;
}

extern (C) void* _aaGetX(void* aa, TypeInfo keyti,
        size_t valuesize, void* pkey);
extern (C) void* _aaGetRvalueX(void* aa, TypeInfo keyti,
        size_t valuesize, void* pkey);
void* aaGetX(void* aa, TypeInfo keyti, size_t valuesize, void* pkey) {
    return _aaGetX(aa, keyti, valuesize, pkey);
}
void* aaGetRvalueX(void* aa, TypeInfo keyti, size_t valuesize, void* pkey) {
    return _aaGetRvalueX(aa, keyti, valuesize, pkey);
}

void* cast_int_int_aa_p_void_p(int[int]* aa) {
    return cast(void*)aa;
}
void* cast_int_int_aa_void_p(int[int] aa) {
    return cast(void*)aa;
}

int* cast_void_p_int_p(void* p) {
    return cast(int*)p;
}

void main() {
    auto ct_env = new CTEnv();

    int[int] bro;
    bro[9] = 123;

    ct_env.autodeclare("a", 10);
    ct_env.autodeclare("b", 2);
    ct_env.autodeclare("mykey", 0);

    ct_env.aadeclare("myaa", bro);

    ct_env.funcdeclare!add_int("$add");
    ct_env.funcdeclare!lt_int("$lt");
    ct_env.funcdeclare!cast_int_bool("$cast_int_bool");
    ct_env.funcdeclare!cast_int_int_aa_p_void_p("$cast_int_int_aa_p_void_p");
    ct_env.funcdeclare!cast_int_int_aa_void_p("$cast_int_int_aa_void_p");
    ct_env.funcdeclare!not("$not");
    ct_env.funcdeclare!aaGetX("$aaGetX");
    ct_env.funcdeclare!aaGetRvalueX("$aaGetRvalueX");
    ct_env.funcdeclare!cast_void_p_int_p("$cast_void_p_int_p");

//    // while (a < 10)
//    //     a = a + 1;
//    auto ir = new IR(IR.Type.sequence, [
//                    new IR(IR.Type.while_, 
//                        new IR(IR.Type.application,
//                            new IR(IR.Type.variable, "$lt_int", ct_env),
//                            [ new IR(IR.Type.variable, "a", ct_env),
//                              new IR(IR.Type.constant, 
//                                      ct_env.get_ti!int(), Val(10)) ]),
//                        new IR(IR.Type.assignment,
//                            new IR(IR.Type.variable, "a", ct_env),
//                            new IR(IR.Type.application,
//                                new IR(IR.Type.variable, "$add_int", ct_env),
//                                [ new IR(IR.Type.variable, "a", ct_env),
//                                  new IR(IR.Type.constant,
//                                          ct_env.get_ti!int(), Val(1)) ]))),
//                    ]);
//    // while (cast(bool)a)
//    //     a = a - 1;
//    auto ir = new IR(IR.Type.sequence, [
//                    new IR(IR.Type.while_, 
//                        new IR(IR.Type.application,
//                            new IR(IR.Type.variable, 
//                                "$cast_int_bool", ct_env),
//                            [ new IR(IR.Type.variable, "a", ct_env) ]),
//                        new IR(IR.Type.assignment,
//                            new IR(IR.Type.variable, "a", ct_env),
//                            new IR(IR.Type.application,
//                                new IR(IR.Type.variable, "$add_int", ct_env),
//                                [ new IR(IR.Type.variable, "a", ct_env),
//                                  new IR(IR.Type.constant, 
//                                      ct_env.get_ti!int(), Val(-1)) ]))),
//                    ]);

    // mykey = 2;
    // myaa[mykey] = 5; // kinda, sorta

    // actually
    // mykey = 2;
    // *cast(int*)($aaGetX(cast(void*)myaa, typeid(mykey), 4u, &mykey)) = 5;
    // which is what will be generated hopefully

    //IR lookup_lv(string aa_name, string var_name) {
    //    return call(id("$aaGetX"),
    //            call(id("$cast_int_int_aa_p_void_p"),
    //                addressof(id(aa_name))),
    //            typeid_(id(var_name)),
    //            constant(ct_env, int.sizeof),
    //            addressof(id(var_name)));
    //}
    //IR lookup_rv(string aa_name, string var_name) {
    //    return call(id("$aaGetRvalueX"),
    //            call(id("$cast_int_int_aa_void_p"),
    //                id(aa_name)),
    //            typeid_(id(var_name)),
    //            constant(ct_env, int.sizeof),
    //            addressof(id(var_name)));
    //}

    //auto ir = seq(
    //        set(id("mykey"), constant(ct_env, 2)),
    //        set(deref(call(id("$cast_void_p_int_p"), lookup_lv("myaa", "mykey"))),
    //            constant(ct_env, 5)),

    //        while_(call(id("$lt_int"),
    //                deref(call(id("$cast_void_p_int_p"), lookup_rv("myaa", "mykey"))),
    //                constant(ct_env, 10)),
    //            seq(
    //                set(deref(call(id("$cast_void_p_int_p"), lookup_lv("myaa", "mykey"))),
    //                    call(id("$add_int"),
    //                        deref(call(id("$cast_void_p_int_p"), lookup_rv("myaa", "mykey"))),
    //                        constant(ct_env, 1)))),
    //            ),
    //        );
    //resolve(ir, ct_env);


    writeln("HI");
    auto sw = StopWatch();
    sw.start();
    auto p = P.make_parser(reduction_table);
    sw.stop();
    writeln("TOOK ", sw.peek().hnsecs / 10_000.0, " ms!",
           " (", p.states.length, ")");

    auto f = File("states.txt", "w");
    foreach (i, state; p.states) {
        f.writeln("state ", i, ":\n", state);
    }

    auto env = ct_env.get_runtime_env();

    while (true) {
        if (p.stack.empty) {
            write("D > ");
        } else {
            write("..> ");
        }
        auto input = readln();

        if (input.empty) {
            writeln();
            break;
        }

        auto lx = Lexer(input);
        
        if (lx.empty) continue;

        //writeln(lx);

        foreach (tok; lx) {
            p.feed(tok);
        }
        p.feed(Token(-1, "", Tok.eof));
        if (p.results.empty) {
            continue;
        }
        //writefln("%(%s;\n%)", p.results);

        foreach (r; p.results) {
            auto ir = r.toIR(ct_env);
            resolve(ir, ct_env);
            if (ir.ti.type != TI.Type.void_) {
                writeln(interpret(ir, env).toString(ir.ti));
            }
        }
        p.results = [];
    }
}
