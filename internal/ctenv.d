module internal.ctenv;

import std.stdio, std.algorithm, std.traits, std.typetuple, std.exception;
import std.conv;

import internal.typeinfo, internal.ir, internal.val, internal.env;


final class CTEnv {

    CTEnv parent;

    // AA of function name -> overload set  (????)
    IR[][string] functions;
    IR[string] vars;

    TI[string] tis;

    ref TI typeof_(string var_name) {
        if (var_name in vars) {
            //writeln(var_name, " has type ", vars[var_name]);
            return vars[var_name].ti;
        }
        enforce (parent !is null, text(var_name, " not in ", vars, " and no parent"));
        return parent.typeof_(var_name);
    }

    IR[] get_function(string func_name) {
        return functions[func_name];
    }

    IR lookup(string name) {
        assert (!(name in functions && name in vars));

        if (name in functions) {
            auto ret = new IR(IR.Type.function_, name);
            ret.ti.type = TI.Type.function_;
            ret.resolved = true;
            return ret;
        } else if (name in vars) {
            auto ret = new IR(IR.Type.variable, name);
            ret.ti = vars[name].ti;
            ret.resolved = true;
            return ret;
        }
        enforce (parent !is null, text(name, " not in env, and no parent"));
        return parent.lookup(name);
    }

    void autodeclare(T)(string name, T t) {
        vars[name] = new IR(IR.Type.constant, get_ti!T(), Val(t));
    }
    void aadeclare(T)(string name, T t) {
        vars[name] = new IR(IR.Type.constant, get_ti!T(), Val(cast(void*)t));
    }
    void funcdeclare(Ts...)(string name) if (Ts.length == 1) {
        alias Ts[0] T;
        functions[name] ~= new IR(IR.Type.constant,
                get_ti!(typeof(&T))(), Val(&wrap!T));
    }

    void declare(TI ti, string name, bool initialize=true) {
        vars[name] = new IR(IR.Type.constant, ti,
                initialize ? init_val(ti) : Val());
    }

    Env get_runtime_env() {
        auto env = new Env;

        foreach (var_name, var_decl; vars) {
            env.declare(var_name, var_decl.val);
        }

        return env;
    }

    void assimilate(Env env) {
        foreach (name, val; env.vars) {
            vars[name].val = val;
        }
        if (parent !is null) {
            parent.assimilate(env.parent);
        }
    }

    ref TI get_ti(T...)() if (T.length == 1) {
        enum s = T.stringof;
        if (s in tis) { return tis[s]; }

        auto ti = make_new_ti!T();

        tis[s] = ti;
        return tis[s];
    }

    private TI make_new_ti(T)() if (isFunctionPointer!T) {
        TI ti;
        ti.pointer = typeid(T);
        ti.type = TI.Type.builtin_function;
        ti.ext_data ~= get_ti!(ReturnType!T)();

        foreach (P; ParameterTypeTuple!T) {
           ti.ext_data ~= get_ti!P();
        }
        return ti;
    }
    private TI make_new_ti(T)() if (isDelegate!T) {
        TI ti;
        ti.type = TI.Type.builtin_delegate;
        ti.ti1 = get_ti!(ReturnType!T);

        foreach (P; ParameterTypeTuple!T) {
           ti.tis ~= get_ti!P();
        }
        return ti;
    }
    private TI make_new_ti(T)() if (!isFunctionPointer!T && is(T U : U*)) {
        static if (is(T U : U*)) { // wtf
            //pragma (msg, U.stringof);
            TI ti;

            ti.type = TI.Type.pointer;
            ti.pointer = typeid(T);

            ti.ext_data ~= get_ti!U();
            return ti;
        } else {
            static assert (0);
        }
    }
    private TI make_new_ti(T)() if (is(T == class)) {
        TI ti;
        ti.type = TI.Type.class_;
        ti.class_ = typeid(T);
        return ti;
    }
    private TI make_new_ti(T)() if (is(T U == U[K], K)) {
        static if (is(T U == U[K], K)) {
            TI ti;

            ti.type = TI.Type.assocarray;
            ti.assoc_array = typeid(T);

            ti.ext_data ~= get_ti!K();
            ti.ext_data ~= get_ti!U();

            return ti;
        } else {
            static assert (0);
        }
    }
    mixin (make_primitive_tis!primitive_types());



    TI get_basic_ti(TI.Type ti_type) {
        switch (ti_type) {
            default: assert (0, text(ti_type));
            foreach (T; primitive_types) {
                case mixin("TI.Type."~T.stringof~"_"): return get_ti!T();
            }
        }
        assert (0);
    }
}

Val init_val(TI ti) {
    switch (ti.type) {
        default: assert (0, text(ti.type));
        case TI.Type.void_: return Val();
        foreach (T; primitive_types) {
            static if (is(T == void)) {} else {
                case mixin("TI.Type."~T.stringof~"_"): return Val(T.init);
            }
        }
    }
    assert (0);
}

string make_primitive_tis(Ts...)() {
    string s;
    foreach (T; Ts) {
        s ~= "
        private TI make_new_ti(T)() if (is(T == " ~ T.stringof ~ ")) {
            TI ti;
            ti.primitive = typeid(" ~ T.stringof ~ ");
            ti.type = TI.Type." ~ T.stringof ~ "_;
            return ti;
        }
        ";
    }
    return s;
}

Val wrap(F...)(Val[] vars) {
    assert (vars.length == ParameterTypeTuple!F.length);
    //pragma (msg, "F[0]("~unpackVars!(ParameterTypeTuple!F)()~")");
    return Val(mixin("F[0]("~unpackVars!(ParameterTypeTuple!F)()~")"));
}

template preUnpackVar(T) {
    static if (is(T U == U*) || is(T == class)) {
        enum preUnpackVar = "cast(" ~ T.stringof ~ ")";
    } else static if (is(T V == V[K], K)) {
        enum preUnpackVar = "*cast(" ~ T.stringof ~ "*)&";
    } else {
        enum preUnpackVar = "";
    }
}
template unpackVar(T) {
    static if (is(T == bool)) {
        enum unpackVar = "bool_val";
    } else static if (is(T == char)) {
        enum unpackVar = "char_val";
    } else static if (is(T == wchar)) {
        enum unpackVar = "wchar_val";
    } else static if (is(T == dchar)) {
        enum unpackVar = "dchar_val";
    } else static if (is(T == byte)) {
        enum unpackVar = "byte_val";
    } else static if (is(T == ubyte)) {
        enum unpackVar = "ubyte_val";
    } else static if (is(T == short)) {
        enum unpackVar = "short_val";
    } else static if (is(T == ushort)) {
        enum unpackVar = "ushort_val";
    } else static if (is(T == int)) {
        enum unpackVar = "int_val";
    } else static if (is(T == uint)) {
        enum unpackVar = "uint_val";
    } else static if (is(T == long)) {
        enum unpackVar = "long_val";
    } else static if (is(T == ulong)) {
        enum unpackVar = "ulong_val";
    } else static if (is(T == float)) {
        enum unpackVar = "float_val";
    } else static if (is(T == double)) {
        enum unpackVar = "double_val";
    } else static if (is(T == real)) {
        enum unpackVar = "real_val";
    } else static if (is(T U == U*)) {
        enum unpackVar = "pointer";
    } else static if (is(T == class)) {
        enum unpackVar = "pointer";
    } else static if (is(T V == V[K], K)) {
        enum unpackVar = "pointer";
    } else {
        static assert (0, T.stringof);
    }
}
string unpackVars(Ts...)(int x = 0) {
    static if (Ts.length == 0) {
        return "";
    } else {
        string first = text(preUnpackVar!(Ts[0]),
                "vars[",x,"].",unpackVar!(Ts[0]));
        if (Ts.length == 1) {
            return first;
        } else {
            return first ~ ", " ~ unpackVars!(Ts[1 .. $])(x+1);
        }
    }
}

