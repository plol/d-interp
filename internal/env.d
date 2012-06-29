module internal.env;

import std.stdio;

import internal.val, internal.typeinfo;

final class Env {

    Env parent;
    Val[string] vars;

    this() {
    }

    void declare(string var_name, Val val) {
        vars[var_name] = val;
    }
    void update(string var_name, Val val) {
        if (var_name in vars) {
            vars[var_name] = val;
        } else {
            assert (parent !is null, 
                    "Attempting to update unknown variable " ~ var_name);
            parent.update(var_name, val);
        }
    }

    ref Val lookup(string var_name) {
        if (var_name in vars) {
            return vars[var_name];
        }
        assert (parent !is null, 
                "Attempting to lookup unknown variable " ~ var_name);
        return parent.lookup(var_name);
    }
}
