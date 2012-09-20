module internal.ir;

import std.stdio, std.exception, std.algorithm, std.array, std.conv;

import internal.val;
import internal.typeinfo;
import internal.env;
import internal.ctenv;
import internal.function_;
import internal.variable;
import stuff;



final class IR {
    enum Type {
        if_,
        while_,
        switch_,

        function_,
        builtin_function,

        variable,
        id,

        up_ref,

        overload_set,

        sequence,

        constant,

        application,

        assignment,

        typeid_,
        typeof_,

        addressof,
        deref,

        return_,

        var_decl,
        var_init,

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
    static struct ID {
        string name;
    }
    static struct Constant {
        Val val;
    }
    static struct OverloadSet {
        string name;
        IR[] set;
    }
    static struct BuiltinFunction {
        string name;
        Val func;
    }
    static struct VarInit {
        string name;
        IR initializer;
    }
    static struct VarDecl {
        IR[] inits;
    }

    union Data {
        If if_;
        While while_;
        Bin bin;
        Application application;
        Constant constant;
        OverloadSet overload_set;
        ID id;

        Function function_;
        Variable variable;

        BuiltinFunction builtin_function;

        IR[] sequence;
        IR next;
        VarInit var_init;
        VarDecl var_decl;
    }

    Type type;

    TI ti;
    bool resolved;

    Data data;
    alias data this;


    bool local() @property {
        switch (type) {
            case Type.variable:
                return variable.local;
            case Type.function_:
                return function_.local;
            case Type.up_ref:
                return true;
            default:
                return false;
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
    this(Type t, TI ti_, Val val1) {
        type = t;
        ti = ti_;
        resolved = true;
        if (t == Type.constant) {
            data.constant = Constant(val1);
        } else {
            assert (0, text(t));
        }
    }
    this(Type t, TI ti_, IR[] irs) {
        type = t;
        ti = ti_;
        if (t == Type.var_decl) {
            data.var_decl = VarDecl(irs);
        } else {
            assert (0, text(t));
        }
    }
    this(Type t, string n, IR ir1) {
        type = t;
        if (t == Type.var_init) {
            data.var_init = VarInit(n, ir1);
        } else {
            assert (0, text(t));
        }
    }
    this(Type t, IR ir1) {
        type = t;
        if (t == Type.typeid_) {
            next = ir1;
        } else if (t == Type.addressof) {
            next = ir1;
        } else if (t == Type.deref) {
            next = ir1;
        } else if (t == Type.return_) {
            next = ir1;
        } else if (t == Type.up_ref) {
            next = ir1;
        } else {
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
        if (t == Type.id) {
            data.id = ID(s);
        } else if (t == Type.overload_set) {
            data.overload_set = OverloadSet(s, []);
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
    this(Type t, TI ti_, string name, Val val) {
        type = t;
        ti = ti_;
        resolved = true;
        if (t == Type.builtin_function) {
            builtin_function = BuiltinFunction(name, val);
        } else {
            assert (0, text(t));
        }
    }
    this(Type t, TI ti_, Function f) {
        type = t;
        ti = ti_;
        if (t == Type.function_) {
            data.function_ = f;
        } else { 
            assert (0);
        }
    }
    this(Type t, Variable v) {
        type = t;
        ti = v.ti;
        if (t == Type.variable) {
            variable = v;
        } else {
            assert (0);
        }
    }

    string get_name() {
        switch (type) {
            default: assert (0);
            case Type.id: return data.id.name;
            case Type.variable: return data.variable.name;
            case Type.function_: return data.function_.name;
            case Type.builtin_function: return data.builtin_function.name;
            case Type.overload_set: return data.overload_set.name;
        }
    }

    string toString() {
        switch (type) {
            case Type.if_:
                return text("if (", data.if_.if_part, ") { ", data.if_.then_part,
                        " } else { ", data.if_.else_part, " }");
            case Type.while_: 
                return text("while (", data.while_.condition, ") { ",
                        data.while_.body_, "} ");
            //case Type.switch_: 
            case Type.function_: return format("function[%s(%(%s, %)) %s]",
                                         get_name(),
                                         data.function_.params,
                                         data.function_.body_);
            case Type.builtin_function:
                return format("builtin[%s]", get_name());
            case Type.variable: return format("var[%s]",get_name());
            case Type.id: return format("id[%s]",get_name());
            case Type.overload_set: return format("overload[%s]", get_name());
            case Type.sequence: return format("{ %(%s; %) }", data.sequence);
            case Type.constant: return data.constant.val.toString(ti);
            case Type.application: return format("%s(%(%s, %))",
                                           data.application.operator,
                                           data.application.operands);
            case Type.assignment: return format("%s = %s",
                                          data.bin.lhs, data.bin.rhs);
            //case Type.typeid_: 
            //case Type.typeof_: 
            //case Type.addressof: 
            //case Type.deref:
            case Type.var_decl: return format("%s %(%s, %);",
                                        ti,
                                        data.var_decl.inits);
            case Type.var_init: {
                                    auto vi = data.var_init;
                                    if (vi.initializer.type == Type.nothing) {
                                        return vi.name;
                                    }
                                    return format("%s = %s", vi.name,
                                            vi.initializer);
                                }

            case Type.nothing: return "(nothing)";
            default: assert (0, text(type));
        }
    }
}

IR call(IR f, IR[] args...) {
    return new IR(IR.Type.application, f, args.dup);
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
IR return_(IR retval) {
    return new IR(IR.Type.return_, retval);
}
