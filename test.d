import std.stdio, std.traits, std.conv;

import std.datetime, std.array, std.typetuple;
import std.typecons, std.file;

import stuff;

import internal.ir, internal.env, internal.val;
import internal.typeinfo, internal.ctenv, internal.typecheck;
import internal.ast2ir, internal.bytecode, internal.bcgen;
import internal.interp;
import entry;


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
    auto ct_env = new CTEnv(true);

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

    writeln("HI");
    P.Parser p;
    auto sw = StopWatch();
    sw.start();
    if (exists("saved_parser")) {
        p = P.load_parser("saved_parser", reduction_table);
    } else {
        p = P.make_parser(reduction_table);
        P.save_parser(p, "saved_parser");
    }
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

            ct_env.return_type.type = TI.Type.unresolved;

            run_code(p, ct_env, "<stdin>", input);
        }
    } else if (args[1] == "--test") {
        writeln("test 0:");
        run_code(p, ct_env, "<test>", q{
                writeln("test 0: ", 12);
                });
        writeln("test 1:");
        run_code(p, ct_env, "<test>", q{

                void foo(int x) {
                    writeln("x = ", x);
                    void bar() {
                        writeln("x = ", x);
                        x = x + 1;
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
                        //writeln("i = ", i);
                        i = i + 1;
                    }
                    writeln("i = ", i);
                }

                foo2(10000);
                writeln("done");
                });
        writeln("test 3:");
        run_code(p, ct_env, "<test>", q{

                auto foo(int x) {
                    writeln("x = ", x);
                    void bar() {
                        writeln("x = ", x);
                        x = x + 1;
                    }
                    bar();
                    x = x + 1;
                    bar();

                    return &bar;
                }

                auto f = foo(12);

                f();
                writeln("done");
                });
    }
}

