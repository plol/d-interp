import std.stdio, std.exception, std.algorithm, std.array, std.conv;

import val;
import typeinfo;
import env;
import ctenv;

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


    TI resolve(CTEnv env) {
        switch (type) {
            default:
                assert (0, text(type));

            case Type.constant:
                return ti;

            case Type.if_:

                auto if_part_type = if_.if_part.resolve(env);
                enforce(env.get_ti!bool() == if_part_type);
                // TODO check for if part type being boolean D:

                if_.then_part.resolve(env);
                if_.else_part.resolve(env);
                return TI.void_;

            case Type.while_:

                auto condition_type = while_.condition.resolve(env);
                // TODO check for while cond type being boolean D:
                while_.body_.resolve(env);
                return TI.void_;

            case Type.application:

                // TODO:
                // We need to find the overloaded function here, or something.
                // otherwise we can't really type check.

                // we assume a unary overload set here,
                // so direct type checking :-)

                TI resolve_in_env(IR ir) {
                    return ir.resolve(env);
                }

                auto arg_types = application.operands
                                            .map!resolve_in_env().array();

                auto assumed_arg_types = application.operator.ti.func_data[1..$];

                enforce(arg_types.length == assumed_arg_types.length);

                foreach (i; 0 .. assumed_arg_types.length) {
                    enforce (arg_types[i] == assumed_arg_types[i]);
                }

                return application.operator.ti.func_data[0];

            case Type.variable:
                return env.typeof_(var_name);
            case Type.sequence:
                foreach (ir; sequence) {
                    ir.resolve(env);
                }
                return TI.void_;
            case Type.assignment:
                auto lhs = bin.lhs.resolve(env);
                auto rhs = bin.rhs.resolve(env);

                // check... O_o

                return lhs;
        }
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
        } else {
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
    this(Type t, string s, CTEnv env) {
        type = t;
        if (t == Type.variable) {
            ti = env.typeof_(s);
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
    this(Type t, IR a, IR[] b) {
        type = t;
        if (t == Type.application) {
            application = Application(a, b);
        } else {
            assert (0);
        }
    }
}
