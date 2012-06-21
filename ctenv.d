import std.stdio, std.algorithm, std.traits, std.typetuple, std.exception;
import std.conv;

import typeinfo;

final class CTEnv {

    CTEnv parent;

    // AA of function name -> overload set
    int[][string] functions;

    TI[string] tis;
    TI[string] vars;


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
        ti.func_data = [get_ti!(ReturnType!T)()];

        foreach (P; ParameterTypeTuple!T) {
           ti.func_data ~= get_ti!P();
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
    private TI make_new_ti(T)() if (is(T == int)) {
        TI ti;
        ti.primitive = typeid(int);
        ti.type = TI.Type.int_;
        return ti;
    }
    private TI make_new_ti(T)() if (is(T == bool)) {
        TI ti;
        ti.primitive = typeid(bool);
        ti.type = TI.Type.bool_;
        return ti;
    }


    void declare(TI ti, string var_name) {
        enforce(var_name !in vars);
        vars[var_name] = ti;
    }

    ref TI typeof_(string var_name) {
        if (var_name in vars) {
            return vars[var_name];
        }
        enforce (parent !is null, text(var_name, " not in ", vars, " and no parent"));
        return parent.typeof_(var_name);
    }

}

