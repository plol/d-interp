module internal.variable;

import internal.val;
import internal.typeinfo;

struct RelativeVarIndex {
    size_t depth;
    size_t index;
}

final class Variable {
    enum Type {
        local,
        global,
    }

    Type type;

    TI ti;
    string name;
    size_t index;

    Val init_val = void;

    private this(TI t, string n) {
        ti = t;
        name = n;
    }

    static Variable new_global(TI ti, string name, Val val) {
        auto v = new Variable(ti, name);
        v.type = Type.global;
        v.init_val = val;
        return v;
    }
    static Variable new_local(TI ti, string name) {
        auto v = new Variable(ti, name);
        v.type = Type.local;
        return v;
    }

    bool local() @property { return type == Type.local; }
    bool global() @property { return type == Type.global; }
}
