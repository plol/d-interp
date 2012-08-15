module internal.typecheck;

import std.conv, std.exception, std.stdio, std.algorithm, std.range;
import internal.typeinfo, internal.ctenv, internal.ir, internal.val;

import stuff;

class SemanticFault : Exception {
    this(string s) {
        super(s);
    }
}

string lotsa_spaces = "                                                        "
~"                                                                             "
~"                                                                             "
~"                                                                             "
~"                                                                             "
~"                                                       "; // True code poetry;
int depth = 0;

bool trace = false;

void pre_resolve(IR ir) {
    if (!trace) return;
    writeln(lotsa_spaces[0 .. depth], "pre  resolve: ", ir);
    depth += 2;
}
void post_resolve(IR ir) {
    if (!trace) return;
    depth -= 2;
    writeln(lotsa_spaces[0 .. depth], "post resolve: ", ir);
}

TI resolve(ref IR ir, CTEnv env) {
    immutable table = [
        IR.Type.if_: &resolve_if,
        IR.Type.while_: &resolve_while,
        IR.Type.variable: &resolve_variable,
        IR.Type.sequence: &resolve_sequence,
        IR.Type.application: &resolve_application,
        IR.Type.assignment: &resolve_assignment,
        IR.Type.typeid_: &resolve_typeid,
        IR.Type.addressof: &resolve_addressof,
        IR.Type.deref: &resolve_deref,
        IR.Type.id: &resolve_id,
        IR.Type.overload_set: &resolve_overload_set,
        IR.Type.return_: &resolve_return,
        IR.Type.var_decl: &resolve_var_decl,
        IR.Type.function_: &resolve_function,
        ];

    if (ir is null) {
        assert (0);
    }
    if (ir.resolved) {
        return ir.ti;
    }
    if (ir.type in table) {
        pre_resolve(ir);
        auto ret = table[ir.type](ir, env);
        ir.ti = ret;
        ir.resolved = true;
        post_resolve(ir);
        return ret;
    }
    assert (0, "wtf bro :D " ~ text(ir.type));
}

TI resolve_typeid(ref IR ir, CTEnv env) {

    auto next_ti = ir.next.resolve(env);
    //writeln("NEXT TI IN TYPEID = ", next_ti);


    TI ti;
    ti.type = TI.Type.class_;
    ti.primitive = typeid(typeid(int)); // BUG

    ir = new IR(IR.Type.constant, ti, Val(next_ti.primitive));

    return ti;
}

TI resolve_addressof(ref IR ir, CTEnv env) {
    auto next_ti = ir.next.resolve(env);

    TI ti;
    ti.type = TI.Type.pointer;

    ti.pointer = new TypeInfo_Pointer;
    ti.pointer.m_next = next_ti.primitive;

    ti.ext_data ~= next_ti;

    return ti;
}

TI resolve_if(ref IR ir, CTEnv env) {

    auto if_part_type = ir.if_.if_part.resolve(env);

    enforce(if_part_type == env.get_ti!bool());

    ir.if_.then_part.resolve(env);
    ir.if_.else_part.resolve(env);

    return TI.void_;
}

TI resolve_while(ref IR ir, CTEnv env) {

    auto condition_type = ir.while_.condition.resolve(env);

    enforce(condition_type == env.get_ti!bool(), text(condition_type, " aint bool"));

    ir.while_.body_.resolve(env);

    return TI.void_;
}

TI resolve_application(ref IR ir, CTEnv env) {

    TI[] arg_types; // = ir.application.operands.map!resolve_in_env().array();
    foreach (ref a; ir.application.operands) {
        arg_types ~= resolve(a, env);
    }

    auto func_type = ir.application.operator.resolve(env);

    if (func_type.type == TI.Type.overload_set) {
        ir.application.operator = overload_set_match(
                ir.application.operator.overload_set.set, arg_types);
        func_type = ir.application.operator.resolve(env);
    }

    auto assumed_arg_types = func_type.operands;

    if (arg_types.length != assumed_arg_types.length) {
        throw new SemanticFault(text(
                    "Wrong number of arguments for ",
                    ir.application.operator.get_name(), "\n",
                    "got ", arg_types.length, ", expected ",
                    assumed_arg_types.length));
    }

    foreach (i; 0 .. assumed_arg_types.length) {
        if (arg_types[i].implicitly_converts_to(assumed_arg_types[i])) {
            continue;
        }
        throw new SemanticFault(
                text("not a match in arg ", i, ":\n",
                    "got:      ", arg_types[i], "\n",
                    "expected: ", assumed_arg_types[i]));

    }

    return func_type.next;
}
bool implicitly_converts_to(TI a, TI b) {
    if (b.type == TI.Type.pointer
            && b.next.type == TI.Type.void_) {
        return a.type == TI.Type.pointer;
    }
    switch (b.type) {
        default: return a == b;

        case TI.Type.int_:
            switch (a.type) {
                default: return false;
                case TI.Type.int_, TI.Type.short_, TI.Type.byte_,
                     TI.Type.bool_:
                         return true;
            }
    }
}

IR overload_set_match(IR[] functions, TI[] arg_types) {
    if (functions.length == 1) {
        return functions[0];
    } else {
        foreach (func; functions) {
            auto func_args = func.ti.operands;
            if (func_args == arg_types) {
                return func;
            }
        }
        throw new SemanticFault("doesnt do best match only perfect match :(");
    }
}

TI resolve_variable(ref IR ir, CTEnv env) {
    return env.typeof_(ir.variable.name);
}

TI resolve_sequence(ref IR ir, CTEnv env) {
    auto res = TI.void_;
    foreach (ref e; ir.sequence) {
        res = e.resolve(env);
    }
    return res;
}

TI resolve_assignment(ref IR ir, CTEnv env) {
    auto lhs = ir.bin.lhs.resolve(env);
    auto rhs = ir.bin.rhs.resolve(env);

    // check... O_o
    enforce(lhs == rhs);

    return lhs;
}

TI resolve_deref(ref IR ir, CTEnv env) {
    auto next = ir.next.resolve(env);
    enforce(next.type == TI.Type.pointer);
    return next.next;
}

TI resolve_id(ref IR ir, CTEnv env) {
    IR res = env.lookup(ir.id.name);
    ir = res;
    return ir.resolve(env);
}

TI resolve_overload_set(ref IR ir, CTEnv env) {
    return TI.overload_set;
}

TI resolve_return(ref IR ir, CTEnv env) {
    TI ret;
    if (ir.next.type == IR.Type.nothing) {
        ret = TI.void_;
    } else {
        ret = ir.next.resolve(env);
    }

    if (env.return_type.type == TI.Type.auto_) {
        env.return_type = ret;
    } else {
        if (ret != env.return_type) {
            throw new SemanticFault(text(
                        "Conflicting types in return statement: ", ret,
                        " (expected ", env.return_type, ")"));
        }
    }
    return ret;
}

TI resolve_function(ref IR ir, CTEnv env) {
    auto func = ir.function_;

    assert (func.env is null);

    auto new_env = env.extend(func.ti.operands, func.params);
    new_env.return_type = func.ti.next;

    func.body_.resolve(new_env);
    func.env = new_env;

    if (func.ti.next.type == TI.Type.auto_) {
        func.ti.next = new_env.return_type;
    }

    env.func_declare(func);

    return TI.void_;
}

TI resolve_var_decl(ref IR ir, CTEnv env) {
    foreach (var; ir.var_decl.inits) {
        auto v = &var.var_init;
        if (v.initializer.type == IR.Type.nothing) {
            if (ir.ti.type == TI.Type.auto_) {
                throw new SemanticFault(
                        "Must have initializer for auto declaration");
            }
            continue;
        }
        v.ti = v.initializer.resolve(env);
        if (ir.ti.type != TI.Type.auto_ && v.ti != ir.ti) {
            throw new SemanticFault(text(
                        "cannot initialize a ", ir.ti, " with a ", v.ti));
        }
        env.var_declare(v.ti, v.name);
    }
    return ir.ti;
}



