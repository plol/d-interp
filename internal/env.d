module internal.env;

import std.stdio, std.array;

import internal.val, internal.typeinfo;
import internal.variable;
import stuff;

final class GlobalVars {
    Val[] vars;
}

final class Env {
    Env parent;
    Val[] vars;

    GlobalVars globals;

    this(size_t n, size_t global_count) {
        vars.length = n;
        globals = new GlobalVars;
        globals.vars.length = global_count;
    }
    this(size_t n, Env p) {
        vars.length = n;
        parent = p;
        globals = p.globals;
    }

    this(size_t n, GlobalVars global_vars) {
        vars.length = n;
        globals = global_vars;
    }

    void update(size_t index, Val val) {
        vars[index] = val;
    }
    ref Val lookup(size_t index) {
        return vars[index];
    }

    Env extend(size_t n) {
        auto ret = new Env(n, this);
        return ret;
    }
}
