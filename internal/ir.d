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
        structdef,
        classdef,
        // etc
        statement,
        expr,
        variable,
        sequence,

        constant,

        application,

        assignment,

        typeid_,
        typeof_,

        addressof,
        deref,

        nothing,

        LAST // DUNNO IF I NEED
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

    Type type;

    TI ti;

    union {
        If if_;
        While while_;
        Bin bin;
        Application application;
        Val val;
        string var_name;
        IR[] sequence;
        IR next;
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
        assert (0);
    }
    this(Type t, TI ti_, Val val1) {
        type = t;
        ti = ti_;
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
            while_ = While(ir1, ir2);
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
            if_ = If(ir1, ir2, ir3);
        } else {
            assert (0);
        }
    }
    this(Type t, string s) {
        type = t;
        if (t == Type.variable) {
            var_name = s;
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
