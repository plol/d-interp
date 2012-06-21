import std.stdio, std.traits, std.conv;

import ir, env, interp, val, typeinfo, ctenv;

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

template unpackVar(T) {
    static if (is(T == int)) {
        enum unpackVar = "int_val";
    } else static if (is(T == bool)) {
        enum unpackVar = "bool_val";
    } else {
        static assert (0);
    }
}



string unpackVars(Ts...)(int x = 0) {
    static if (Ts.length == 0) {
        return "";
    } else {
        string first = text("vars[",x,"].",unpackVar!(Ts[0]));
        if (Ts.length == 1) {
            return first;
        } else {
            return first ~ ", " ~ unpackVars!(Ts[1 .. $])(x+1);
        }
    }
}



Val wrap(F...)(Val[] vars) {
    assert (vars.length == ParameterTypeTuple!F.length);
    return Val(mixin("F[0]("~unpackVars!(ParameterTypeTuple!F)()~")"));
}




void main() {
    auto ct_env = new CTEnv();

    auto _add_int = &add_int;
    auto _lt_int = &lt_int;

    ct_env.declare(ct_env.get_ti!int(), "a");
    ct_env.declare(ct_env.get_ti!int(), "b");
    ct_env.declare(ct_env.get_ti!(typeof(_add_int))(), "$add_int");
    ct_env.declare(ct_env.get_ti!(typeof(_lt_int))(), "$lt_int");

    auto ir = new IR(IR.Type.sequence, [
                    new IR(IR.Type.while_, 
                        new IR(IR.Type.application,
                            new IR(IR.Type.variable, "$lt_int", ct_env),
                            [ new IR(IR.Type.variable, "a", ct_env),
                              new IR(IR.Type.constant, ct_env.get_ti!int(), Val(10)) ]),
                        new IR(IR.Type.assignment,
                            new IR(IR.Type.variable, "a", ct_env),
                            new IR(IR.Type.application,
                                new IR(IR.Type.variable, "$add_int", ct_env),
                                [ new IR(IR.Type.variable, "a", ct_env),
                                  new IR(IR.Type.constant, ct_env.get_ti!int(), Val(1)) ]))),
                    ]);

    ir.resolve(ct_env);

    auto env = new Env();
    env.declare("a", Val(1));
    env.declare("b", Val(2));
    env.declare("$lt_int", Val(&wrap!(lt_int)));
    env.declare("$add_int", Val(&wrap!(add_int)));

    writeln(interpret(ir, env).toString(ct_env.get_ti!int()));
    writeln(interpret(new IR(IR.Type.variable, "a", ct_env), env).toString(ct_env.get_ti!int()));
}
