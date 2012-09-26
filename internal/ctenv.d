module internal.ctenv;

import std.stdio, std.algorithm, std.traits, std.typetuple, std.exception;
import std.conv, std.array;

import internal.typeinfo, internal.ir, internal.val, internal.env;
import internal.typecheck, internal.function_;
import internal.variable;

import internal.bcgen;

final class GlobalEnv {
    IR[] global_vars;

    Variable insert(TI ti, string name, Val val) {
        auto v = new IR(IR.Type.variable, Variable.new_global(ti, name, val));
        global_vars ~= v;
        v.variable.index = global_vars.length - 1;
        return v.variable;
    }
}


final class CTEnv {

    CTEnv parent;

    GlobalEnv globals;

    IR[string] table;

    TI[string] tis;

    size_t var_count;
    TI return_type;

    bool overwrite;

    bool global() @property {
        return parent is null;
    }

    ref TI typeof_(string name) {
        assert (0, name);
    }

    IR lookup(string name) {

        if (name in table) {
            return table[name];
        }
        if (parent is null) {
            throw new SemanticFault(
                    text("undefined identifier ", name));
        }

        auto ret = parent.lookup(name);
        if (ret.local) {
            ret = new IR(IR.Type.up_ref, ret);
            table[name] = ret;
        }
        return ret;
    }

    void autodeclare(T)(string name, T t) {
        global_var_declare(get_ti!T(), name, Val(t));
    }

    void aadeclare(T)(string name, T t) {
        global_var_declare(get_ti!T(), name, Val(cast(void*)t));
    }

    IR global_var_declare(TI ti, string name, Val val) {
        enforce(overwrite || name !in table);

        auto var = globals.insert(ti, name, val);

        auto ir = new IR(IR.Type.variable, var);
        table[name] = ir;

        return ir;
    }

    private void insert_into_overload_set(string name, IR ir) {
        if (name in table && table[name].type == IR.Type.overload_set) {
            // it's all good
        } else if (overwrite || name !in table) {
            table[name] = new IR(IR.Type.overload_set, name);
        } else {
            enforce(false);
        }
        table[name].overload_set.set ~= ir;
    }

    void builtin_func_declare(Ts...)(string name) if (Ts.length == 1) {
        alias Ts[0] T;
        static assert (isFunctionPointer!(typeof(&T)));

        auto ir = new IR(IR.Type.constant,
                get_ti!(typeof(&T))(), Val(&wrap!T));
        ir.resolved = true;

        insert_into_overload_set(name, ir);
    }

    IR var_declare(TI ti, string name) {
        enforce(overwrite || name !in table);

        auto var = Variable.new_local(ti, name);
        var.index = var_count;

        auto ir = new IR(IR.Type.variable, var);
        table[name] = ir;

        var_count += 1;

        return ir;
    }

    void func_declare(Function func) {
        auto name = func.name;
        if (global) {
            insert_into_overload_set(name, new IR(IR.Type.constant,
                        func.ti, Val(func)));
        } else {
            enforce(overwrite || name !in table);
            table[name] = new IR(IR.Type.constant, func.ti, Val(func));
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
    private TI make_new_ti(T)() if (is(T U == U[])) {
        static if (is(T U == U[])) {
            TI ti;

            ti.type = TI.Type.array;
            ti.array = typeid(T);

            ti.ext_data ~= get_ti!U();

            return ti;
        } else {
            static assert (0);
        }
    }

    private TI make_new_ti(T)() if (is (T == immutable)) {
        static if (is (T U == immutable(U))) {
            return get_ti!U();
        } else {
            static assert (0);
        }
    }
    private TI make_new_ti(T)() if (is (T == const)) {
        static if (is (T U == const(U))) {
            return get_ti!U();
        } else {
            static assert (0);
        }
    }
    mixin (make_primitive_tis!primitive_types());

    TI get_basic_ti(TI.Type ti_type) {
        switch (ti_type) {
            default: assert (0, text(ti_type));
            case TI.Type.auto_: return TI(TI.Type.auto_,[]);
            foreach (T; primitive_types) {
                case mixin("TI.Type."~T.stringof~"_"): return get_ti!T();
            }
        }
        assert (0);
    }

    CTEnv extend(TI[] param_types, string[] names) {
        auto ret = new CTEnv(this);
        foreach (i; 0 .. param_types.length) {
            if (names[i].empty) {
                continue;
            }
            ret.var_declare(param_types[i], names[i]);
        }
        return ret;
    }
    
    this(bool allow_overwriting_declarations=false) {
        globals = new GlobalEnv;
        overwrite = allow_overwriting_declarations;
    }
    this(CTEnv p) {
        parent = p;
        globals = p.globals;
        tis = p.tis;
    }
}

Val init_val(TI ti) {
    switch (ti.type) {
        default: assert (0, text(ti.type));
        case TI.Type.function_: return Val();
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
    static if (is(ReturnType!(F[0]) == void)) {
        mixin("F[0]("~unpackVars!(ParameterTypeTuple!F)()~");");
        return Val.void_;
    } else {
        return Val(mixin("F[0]("~unpackVars!(ParameterTypeTuple!F)()~")"));
    }
}

template preUnpackVar(T) {
    static if (is(T U == U*) || is(T == class) || is(T U == U[])) {
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
    } else static if (is(T U == U[])) {
        enum unpackVar = "array";
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

Env get_runtime_env(CTEnv ct_env) {
    assert (ct_env.global);
    auto env = new Env(ct_env.var_count, ct_env.globals.global_vars.length);

    update_env(ct_env, env);
    return env;
}

void update_env(CTEnv ct_env, Env env) {
    assert (ct_env.global);
    env.globals.vars.length = ct_env.globals.global_vars.length;
    foreach (i; 0 .. ct_env.globals.global_vars.length) {
        env.globals.vars[i] = ct_env.globals.global_vars[i].variable.init_val;
    }
}

void assimilate(CTEnv ct_env, Env env) {
    assert (ct_env.global);
    foreach (i; 0 .. ct_env.globals.global_vars.length) {
        ct_env.globals.global_vars[i].variable.init_val = env.globals.vars[i];
    }
}

