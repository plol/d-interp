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

    this(string n, Val val) {
        name = n;
        type = Type.global;
        init_val = val;
    }
    this(string n) {
        name = n;
        type = Type.local;
    }

    bool local() @property { return type == Type.local; }
    bool global() @property { return type == Type.global; }
}
