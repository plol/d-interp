import std.stdio, std.traits, std.conv;

import std.datetime, std.array, std.typetuple;
import std.typecons;

import stuff;

import internal.ir, internal.env, internal.interp, internal.val;
import internal.typeinfo, internal.ctenv, internal.typecheck;
import internal.ast2ir;

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

int test_int_shit(int a, int b) {
    return a+b;
}

auto add(T, U)(T t, U u) {
    return t + u;
}
auto sub(T, U)(T t, U u) {
    return t - u;
}
auto div(T, U)(T t, U u) {
    return t / u;
}
auto mul(T, U)(T t, U u) {
    return t * u;
}

void heh_crash() {
    assert (0);
}

void main(string[] args) {
    auto ct_env = new CTEnv();

    int[int] bro;
    bro[9] = 123;

    ct_env.autodeclare("a", 10);
    ct_env.autodeclare("b", 2);
    ct_env.autodeclare("mykey", 0);

    ct_env.aadeclare("myaa", bro);

    foreach (T; TypeTuple!(bool, char, wchar, dchar, byte, ubyte, short, ushort,
                int, uint, long, ulong, float, double, real)) {
    //    foreach (U; TypeTuple!(bool, char, wchar, dchar, byte, ubyte, short, ushort,
    //                int, uint, long, ulong, float, double, real)) {
        alias T U;
            ct_env.builtin_func_declare!(add!(T, U))("$add");
    //        ct_env.funcdeclare!(sub!(T, U))("$sub");
    //        ct_env.funcdeclare!(div!(T, U))("$div");
    //        ct_env.funcdeclare!(mul!(T, U))("$mul");
    //    }
    }
    ct_env.builtin_func_declare!lt_int("$lt");
    ct_env.builtin_func_declare!cast_int_bool("$cast_int_bool");
    ct_env.builtin_func_declare!cast_int_int_aa_p_void_p("$cast_int_int_aa_p_void_p");
    ct_env.builtin_func_declare!cast_int_int_aa_void_p("$cast_int_int_aa_void_p");
    ct_env.builtin_func_declare!not("$not");
    ct_env.builtin_func_declare!aaGetX("$aaGetX");
    ct_env.builtin_func_declare!aaGetRvalueX("$aaGetRvalueX");
    ct_env.builtin_func_declare!cast_void_p_int_p("$cast_void_p_int_p");
    ct_env.builtin_func_declare!(writeln!string)("writeln");
    ct_env.builtin_func_declare!(writeln!(string, int))("writeln");
    ct_env.builtin_func_declare!(heh_crash)("heh_crash");

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

    if (args.length == 1) {
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

            if (input == "__env\n") {
                writeln(ct_env.get_runtime_env().vars);
                continue;
            }

            run_code(p, ct_env, "<stdin>", input);
        }
    } else if (args[1] == "--test") {
        writeln("test 1:");
        run_code(p, ct_env, "<test>", q{
                void foo(int x) {
                    writeln("x = ", x);
                    void bar() {
                        writeln("x = ", x);
                    }
                    bar();
                    x = x + 1;
                    bar();
                }

                foo(12);
                writeln("done");
                });
        writeln("test 2:");
        run_code(p, ct_env, "<test>", q{
                void foo2(int x) {
                    int i;
                    while (i < x) {
                        writeln("i = ", i);
                        i = i + 1;
                        if (i < 377) {
                            
                        } else {
                            heh_crash();
                        }
                    }
                }

                foo2(10000);
                writeln("done");
                });
    }
}

void print_throwable(Throwable t) {
    writefln("%s@%s(%s): %s", t.classinfo.name, t.file, t.line, t.msg);
    bool lulz;
    ulong x;
    foreach (i, s; t.info) {
        if (i < 600) {
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

void run_code(ref P.Parser p, ref CTEnv ct_env, string file, string input) {
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
    //writefln("%(%s\n%)", p.results); p.results = []; continue;

    Val val;

    Cont cont;
    cont.succeed = (Val v, FailCont) {
        val = v;
    };
    cont.fail = (InterpretedException ex) {
        throw ex;
    };

    foreach (r; p.results) {
        auto ir = toIR(r, ct_env);
        if (ir is null) continue;

        try {
            resolve(ir, ct_env);
            ct_env.resolve_functions();
        } catch (SemanticFault f) {
            writeln("error ", r.loc, ": ", f.msg);
            break;
        }

        auto env = ct_env.get_runtime_env();
        try {
            ir.interpret(env, cont);
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

