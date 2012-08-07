module internal.env;

import std.stdio, std.array;

import internal.val, internal.typeinfo;
import stuff;

final class Env {
    Env parent;
    Env static_env;
    Val[string] vars;

    this(Env p=null, Env static_ = null) {
        parent = p;
        if (static_ is null) {
            static_env = this;
        } else {
            static_env = static_;
        }
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

    Env extend() {
        auto ret = new Env(this, static_env);
        return ret;
    }

    string toString() {
        if (parent is null) {
            return format("%s", vars.byKey);
        } else {
            return format("%s\nwith parent:\n%s", vars.byKey, parent);
        }
    }
}
