import std.stdio, std.traits, std.conv;

import internal.ir, internal.env, internal.interp, internal.val;
import internal.typeinfo, internal.ctenv, internal.typecheck;

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
int lt_int(int a, int b) {
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

int* cast_void_p_int_p(void* p) {
    return cast(int*)p;
}



IR call_var(string f, IR[] args...) {
    return new IR(IR.Type.application,
            new IR(IR.Type.variable, f),
            args.dup);
}

IR var(string n) {
    return new IR(IR.Type.variable, n);
}
IR deref(IR ir) {
    return new IR(IR.Type.deref, ir);
}
IR set(IR lhs, IR rhs) {
    return new IR(IR.Type.assignment, lhs, rhs);
}

IR constant(T)(CTEnv ct_env, T t) {
    return new IR(IR.Type.constant, ct_env.get_ti!T(), Val(t));
}
IR seq(IR[] ss...) {
    return new IR(IR.Type.sequence, ss.dup);
}

IR addressof(IR ir) {
    return new IR(IR.Type.addressof, ir);
}

IR typeid_(IR ir) {
    return new IR(IR.Type.typeid_, ir);
}


void main() {
    auto ct_env = new CTEnv();

    int[int] bro;
    bro[9] = 123;

    ct_env.autodeclare("a", 10);
    ct_env.autodeclare("b", 2);
    ct_env.autodeclare("mykey", 0);

    ct_env.aadeclare("myaa", bro);

    ct_env.funcdeclare!add_int("$add_int");
    ct_env.funcdeclare!lt_int("$lt_int");
    ct_env.funcdeclare!cast_int_bool("$cast_int_bool");
    ct_env.funcdeclare!cast_int_int_aa_p_void_p("$cast_int_int_aa_p_void_p");
    ct_env.funcdeclare!not("$not");
    ct_env.funcdeclare!aaGetX("$aaGetX");
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

    auto lookup_ir = call_var("$aaGetX",
            call_var("$cast_int_int_aa_p_void_p",
                addressof(var("myaa"))),
            typeid_(var("mykey")),
            constant(ct_env, 4u),
            addressof(var("mykey")));

    auto ir = seq(
            set(var("mykey"), constant(ct_env, 2)),
            set(deref(call_var("$cast_void_p_int_p", lookup_ir)),
                constant(ct_env, 5)),
            );
    resolve(ir, ct_env);

    auto env = ct_env.get_runtime_env();

    writeln(interpret(ir, env).toString(ct_env.get_ti!int()));
    writeln(env.vars["myaa"].toString(ct_env.get_ti!(int[int])()));
    writeln(bro);
}
