import std.stdio;

import val;

final class Env {
    Env parent;
    Val[string] vars;

    this() {
        declare("$add_int", Val( (Val[] vars) {
                    assert (vars.length == 2);
                    return Val(vars[0].int_val + vars[1].int_val);
                    }));
        declare("$add_float", Val(true));
        declare("$add_double", Val(true));
        declare("$add_real", Val(true));
        declare("$cast", Val(true));
    }

    void declare(string var_name, Val val) {
        vars[var_name] = val;
    }
    void update(string var_name, Val val) {
        if (var_name in vars) {
            vars[var_name] = val;
        }
        assert (parent !is null, 
                "Attempting to update unknown variable " ~ var_name);
        parent.update(var_name, val);
    }

    Val lookup(string var_name) {
        if (var_name in vars) {
            return vars[var_name];
        }
        assert (parent !is null, 
                "Attempting to lookup unknown variable " ~ var_name);
        return parent.lookup(var_name);
    }
}
