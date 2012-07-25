module internal.ir;

import std.stdio, std.exception, std.algorithm, std.array, std.conv;

import internal.val;
import internal.typeinfo;
import internal.env;
import internal.ctenv;

final class IR {
    enum Type {
        if_,
        while_,
        switch_,
        // etc

        variable,
        function_,
        id,

        sequence,

        constant,

        application,

        assignment,

        typeid_,
        typeof_,

        addressof,
        deref,

        nothing,
    }
    static struct If {
        IR if_part, then_part, else_part;
    }
    static struct While {
        IR condition, body_;
    }
    static struct Bin {
        IR lhs, rhs;
    }
    static struct Application {
        IR operator;
        IR[] operands;
    }

    union Data {
        If if_;
        While while_;
        Bin bin;
        Application application;
        Val val;
        string name;
        IR[] sequence;
        IR next;
    }

    Type type;
    TI ti;
    bool resolved;
    Data data;
    alias data this;


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
        assert (0);
    }
    this(Type t, TI ti_, Val val1) {
        type = t;
        ti = ti_;
        resolved = true;
        if (t == Type.constant) {
            val = val1;
        } else {
            assert (0);
        }
    }
    this(Type t, Val val1, Val val2) {
        assert (0);
    }
    this(Type t, IR ir1) {
        type = t;
        if (t == Type.typeid_) {
            next = ir1;
        } else if (t == Type.addressof) {
            next = ir1;
        } else if (t == Type.typeid_) {
            next = ir1;
        } else if (t == Type.deref) {
            next = ir1;
        } else{
            assert (0);
        }
    }
    this(Type t, IR ir1, IR ir2) {
        type = t;
        if (t == Type.while_) {
            data.while_ = While(ir1, ir2);
        } else if (t == Type.assignment) {
            bin = Bin(ir1, ir2);
            ti = ir2.ti;
        } else {
            assert (0);
        }
    }
    this(Type t, IR ir1, IR ir2, IR ir3) {
        type = t;
        if (t == Type.if_) {
            data.if_ = If(ir1, ir2, ir3);
        } else {
            assert (0);
        }
    }
    this(Type t, string s) {
        type = t;
        if (t == Type.variable) {
            name = s;
        } else if (t == Type.function_) {
            name = s;
        } else if (t == Type.id) {
            name = s;
        } else {
            assert (0, to!string(t));
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
    this(Type t, IR a, IR[] b) {
        type = t;
        if (t == Type.application) {
            application = Application(a, b);
        } else {
            assert (0);
        }
    }
}

IR call(IR f, IR[] args...) {
    return new IR(IR.Type.application, f, args.dup);
}

IR var(string n) {
    return new IR(IR.Type.variable, n);
}
IR fun(string n) {
    return new IR(IR.Type.function_, n);
}
IR id(string n) {
    return new IR(IR.Type.id, n);
}
IR deref(IR ir) {
    return new IR(IR.Type.deref, ir);
}
IR set(IR lhs, IR rhs) {
    return new IR(IR.Type.assignment, lhs, rhs);
}

IR constant(T)(CTEnv ct_env, T t) {
    return new IR(IR.Type.constant, ct_env.get_ti!T(), Val(t));
}
IR seq(IR[] ss...) {
    return new IR(IR.Type.sequence, ss.dup);
}

IR addressof(IR ir) {
    return new IR(IR.Type.addressof, ir);
}

IR typeid_(IR ir) {
    return new IR(IR.Type.typeid_, ir);
}

IR if_(IR if_part, IR then_part, IR else_part) {
    return new IR(IR.Type.if_, if_part, then_part, else_part);
}
IR while_(IR cond, IR body_) {
    return new IR(IR.Type.while_, cond, body_);
}
IR nothing() {
    return new IR(IR.Type.nothing);
}
