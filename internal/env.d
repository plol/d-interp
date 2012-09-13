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

    private Env get_with_depth(size_t depth) {
        auto e = this;
        while (depth > 0) {
            assert (e.parent !is null, "no parent for dynamic environment");
            e = e.parent;
            depth -= 1;
        }
        return e;
    }
    void update(RelativeVarIndex rel, Val val) {
        get_with_depth(rel.depth).vars[rel.index] = val;
    }
    ref Val lookup(RelativeVarIndex rel) {
        return get_with_depth(rel.depth).vars[rel.index];
    }

    Env extend(size_t n) {
        auto ret = new Env(n, this);
        return ret;
    }
}
