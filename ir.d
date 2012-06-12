import std.stdio;

import val;

final class IR {
    enum Type {
        if_,
        while_,
        switch_,
        struct_,
        class_,
        // etc
        statement,
        expr,
        variable,
        sequence,

        constant,

        nothing,

        LAST // DUNNO IF I NEED
    }
    static struct IF {
        IR if_part, then_part, else_part;
    }
    static struct BIN {
        IR lhs, rhs;
    }

    Type type;

    union {
        IF if_;
        BIN bin;
        Val val;
        string var_name;
        IR[] sequence;
    }

    this(Type t) {
        type = t;
        if (t == Type.nothing) {
            // nothing :D
        } else {
            assert (0);
        }
    }
    this(Type t, Val val1) {
        type = t;
        if (t == Type.constant) {
            val = val1;
        } else {
            assert (0);
        }
    }
    this(Type t, Val val1, Val val2) {
        type = t;
        assert (0);
    }
    this(Type t, IR ir1) {
        type = t;
        assert (0);
    }
    this(Type t, IR ir1, IR ir2) {
        type = t;
        assert (0);
    }
    this(Type t, IR ir1, IR ir2, IR ir3) {
        type = t;
        if (t == Type.if_) {
            if_ = IF(ir1, ir2, ir3);
        } else {
            assert (0);
        }
    }
    this(Type t, string s) {
        type = t;
        if (t == Type.variable) {
            var_name = s;
        } else {
            assert (0);
        }
    }
    this(Type t, IR[] seq) {
        type = t;
        if (t == Type.sequence) {
            sequence = seq;
        } else {
            assert (0);
        }
    }
}
