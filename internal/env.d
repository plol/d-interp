module internal.env;

import std.stdio, std.array;

import internal.val, internal.typeinfo;
import internal.variable;
import stuff;

final class Env {
    Env parent;
    Val[] vars;

    this(size_t n, Env p=null) {
        vars.length = n;
        parent = p;
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
