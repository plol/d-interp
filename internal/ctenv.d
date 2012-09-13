module internal.ctenv;

import std.stdio, std.algorithm, std.traits, std.typetuple, std.exception;
import std.conv, std.array;

import internal.typeinfo, internal.ir, internal.val, internal.env;
import internal.typecheck, internal.function_;
import internal.variable;

import internal.bcgen;


struct Sym {
    enum Type {
        variable,
        alias_,
        function_,
    }

    Type type;

    size_t depth;
}

final class CTEnv {

    CTEnv parent;

    Sym[] symbols;

    TI[string] tis;

    TI return_type;

    bool global() @property {
        return parent is null;
    }

    ref TI typeof_(string var_name) {
        assert (0);
    }

    IR lookup(string name) {
        assert (!(name in functions && name in vars));

        if (name in functions) {
            return functions[name];
        } else if (name in vars) {
            return vars[name];
        }
        if (parent is null) {
            throw new SemanticFault(
                    text("undefined identifier ", name));
        }

        return parent.lookup(name);
    }

    RelativeVarIndex get_local_var_index(string name) {
        auto e = this;
        size_t depth = 0;

        while (name !in e.vars) {
            depth += 1;
            assert (e.parent !is null);
            e = e.parent;
        }
        return RelativeVarIndex(depth, e.vars[name].variable.local);
    }



    void autodeclare(T)(string name, T t) {
        var_declare(get_ti!T(), name, Val(t));
    }

    void aadeclare(T)(string name, T t) {
        var_declare(get_ti!T(), name, Val(cast(void*)t));
    }

    void builtin_func_declare(Ts...)(string name) if (Ts.length == 1) {
        alias Ts[0] T;
        static assert (isFunctionPointer!(typeof(&T)));

        if (name !in functions) {
            functions[name] = new IR(IR.Type.overload_set, name);
        }

        auto ir = new IR(IR.Type.constant,
                get_ti!(typeof(&T))(), Val(&wrap!T));
        ir.resolved = true;
            
        functions[name].overload_set.set ~= ir;
    }

    void var_declare(TI ti, string name) {
        var_declare(ti, name, init_val(ti));
    }
    void var_declare(TI ti, string name, Val val) {
        vars[name] = new IR(IR.Type.variable, ti, name, val);
    }

    void func_declare(Function func) {
        auto name = func.name;
        if (global) {
            if (name !in functions) {
                functions[name] = new IR(IR.Type.overload_set, name);
            }
            functions[name].overload_set.set ~= new IR(IR.Type.constant,
                    func.ti, Val(func));
        } else {
            functions[name] = new IR(IR.Type.constant, func.ti, Val(func));
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
        auto ret = new CTEnv;
        ret.parent = this;
        ret.tis = tis;
        foreach (i; 0 .. param_types.length) {
            if (names[i].empty) {
                continue;
            }
            ret.var_declare(param_types[i], names[i]);
        }

        return ret;
    }

    void resolve_functions() {
        foreach (os; functions) {
            foreach (ref func; os.overload_set.set) {
                if (func.ti.type == TI.Type.builtin_delegate
                 || func.ti.type == TI.Type.builtin_function) {
                    continue;
                }
                resolve(func.function_.body_, func.function_.env);
                func.function_.env.resolve_functions();
            }
        }
    }
    void generate_bytecode_for_functions() {
        foreach (os; functions) {
            foreach (func; os.overload_set.set) {
                if (func.ti.type == TI.Type.builtin_delegate
                        || func.ti.type == TI.Type.builtin_function) {
                    continue;
                }
                func.function_.bc = 
                    func.function_.body_.generate_bytecode(func.function_.env);
                func.function_.env.resolve_functions();
            }
        }
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
    auto env = new Env(ct_env.vars.length);

    foreach (var_name, var_decl; ct_env.vars) {
        //env.declare(var_name, var_decl.variable.global.init_val);
    }

    return env;
}

void assimilate(CTEnv ct_env, Env env) {
    assert (ct_env.global);
    foreach (name, val; ct_env.vars) {
        auto var = val.variable;
        var.init_val = env.vars[var.index];
    }
}

