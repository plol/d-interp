module internal.env;

import std.stdio, std.array;

import internal.val, internal.typeinfo;
import stuff;

final class Env {
    Env parent;
    Val[] vars;

    this(Env p=null) {
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
    void update(size_t depth, size_t index, Val val) {
        get_with_depth(depth).vars[index] = val;
    }
    ref Val lookup(size_t depth, size_t index) {
        return get_with_depth(depth).vars[index];
    }

    Env extend(size_t n) {
        auto ret = new Env(this);
        ret.vars.length = n;
        return ret;
    }
}
