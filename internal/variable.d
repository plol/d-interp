

final class Variable {
    enum Type {
        local,
        global,
    }
    static struct Local {
        size_t depth;
        size_t index;
    }
    static struct Global {
        size_t index;
        Val init_val;
    }

    union PossibleValues {
        Local local;
        Global global;
    }


    Type type;

    TI ti;
    string name;

    PossibleValues values;
    alias values this;

    this(string n, Val val) {
        name = n;
        type = Type.global;
        global = Global(0, val);
    }
    this(string n) {
        name = n;
        type = Type.local;
        local = Local(0, 0);
    }

    bool local() @property { return type == Type.local; }
    bool global() @property { return type == Type.global; }
    
}
