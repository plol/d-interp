module internal.ctenv;

import std.stdio, std.algorithm, std.traits, std.typetuple, std.exception;
import std.conv;

import internal.typeinfo, internal.ir, internal.val, internal.env;


final class CTEnv {

    CTEnv parent;

    // AA of function name -> overload set  (????)
    IR[][string] functions;

    TI[string] tis;

    struct VarDecl {
        TI ti;
        bool has_initializer;
        Val val;
    }

    VarDecl[string] vars;

    ref TI typeof_(string var_name) {
        if (var_name in vars) {
            //writeln(var_name, " has type ", vars[var_name]);
            return vars[var_name].ti;
        }
        enforce (parent !is null, text(var_name, " not in ", vars, " and no parent"));
        return parent.typeof_(var_name);
    }

    void autodeclare(T)(string name, T t) {
        vars[name] = VarDecl(get_ti!T(), true, Val(t));
    }
    void aadeclare(T)(string name, T t) {
        vars[name] = VarDecl(get_ti!T(), true, Val(cast(void*)t));
    }
    void funcdeclare(Ts...)(string name) if (Ts.length == 1) {
        alias Ts[0] T;
        vars[name] = VarDecl(get_ti!(typeof(&T))(), true, Val(&wrap!T));
    }

    Env get_runtime_env() {
        auto env = new Env;

        foreach (var_name, var_decl; vars) {
            assert (var_decl.has_initializer);
            env.declare(var_name, var_decl.val);
        }

        return env;
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
    } else {
        enum preUnpackVar = "";
    }
}
template unpackVar(T) {
    static if (is(T == int)) {
        enum unpackVar = "int_val";
    } else static if (is(T == uint)) {
        enum unpackVar = "uint_val";
    } else static if (is(T == bool)) {
        enum unpackVar = "bool_val";
    } else static if (is(T U == U*)) {
        enum unpackVar = "pointer";
    } else static if (is(T == class)) {
        enum unpackVar = "pointer";
    } else static if (is(T V == V[K], K)) {
        enum unpackVar = "pointer";
    } else {
        static assert (0);
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

