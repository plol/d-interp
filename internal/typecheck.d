module internal.typecheck;

import std.conv, std.exception, std.stdio, std.algorithm, std.range;
import internal.typeinfo, internal.ctenv, internal.ir, internal.val;

TI resolve(IR ir, CTEnv env) {
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
        ];

    if (ir is null) {
        return TI.void_;
    }
    if (ir.resolved) {
        return ir.ti;
    }
    if (ir.type in table) {
        auto ret = table[ir.type](ir, env);
        ir.ti = ret;
        ir.resolved = true;
        return ret;
    }
    assert (0, "wtf bro :D");
}

TI resolve_typeid(IR ir, CTEnv env) {

    auto next_ti = ir.next.resolve(env);
    //writeln("NEXT TI IN TYPEID = ", next_ti);

    // swap type to constant :-)
    ir.type = IR.Type.constant;
    ir.val = Val(next_ti.primitive);

    TI ti;
    ti.type = TI.Type.class_;
    ti.primitive = typeid(typeid(int)); // BUG

    return ti;
}

TI resolve_addressof(IR ir, CTEnv env) {
    auto next_ti = ir.next.resolve(env);

    TI ti;
    ti.type = TI.Type.pointer;

    ti.pointer = new TypeInfo_Pointer;
    ti.pointer.m_next = next_ti.primitive;

    ti.ext_data ~= next_ti;

    return ti;
}

TI resolve_if(IR ir, CTEnv env) {

    auto if_part_type = ir.if_.if_part.resolve(env);

    enforce(if_part_type == env.get_ti!bool());

    ir.if_.then_part.resolve(env);
    ir.if_.else_part.resolve(env);

    return TI.void_;
}

TI resolve_while(IR ir, CTEnv env) {

    auto condition_type = ir.while_.condition.resolve(env);

    enforce(condition_type == env.get_ti!bool(), text(condition_type, " aint bool"));

    ir.while_.body_.resolve(env);

    return TI.void_;
}

TI resolve_application(IR ir, CTEnv env) {

    // TODO:
    // We need to find the overloaded function here, or something.
    // otherwise we can't really type check.

    // we assume a unary overload set here,
    // so direct type checking :-)

    //TI resolve_in_env(IR ir) {
    //    return resolve(ir, env);
    //}

    TI[] arg_types; // = ir.application.operands.map!resolve_in_env().array();
    foreach (a; ir.application.operands) {
        arg_types ~= resolve(a, env);
    }

    ir.application.operator.resolve(env);

    auto op = ir.application.operator;
    if (op.type == IR.Type.function_) {
        // swap type to constant, DO OVERLOADING RESOLUTION, ifti? D:
        ir.application.operator =
            resolve_overload_set(env.get_function(op.name), arg_types);
    } else if (op.type == IR.Type.variable) {
        // do nothing i guess
        assert (0);
    } else {
        assert (0, "can only call functions and variables (?)");
    }

    auto func_type = ir.application.operator.resolve(env);

    auto assumed_arg_types = func_type.operands;

    enforce(arg_types.length == assumed_arg_types.length);

    foreach (i; 0 .. assumed_arg_types.length) {
        if (assumed_arg_types[i].type == TI.Type.pointer
                && assumed_arg_types[i].next.type == TI.Type.void_) {
            continue;
        }
        enforce (arg_types[i] == assumed_arg_types[i],
                text("not a match in arg ", i, ":\n",
                    "got:      ", arg_types[i], "\n",
                    "expected: ", assumed_arg_types[i]));

    }

    return func_type.next;
}

IR resolve_overload_set(IR[] functions, TI[] arg_types) {
    if (functions.length == 1) {
        return functions[0];
    } else {
        foreach (func; functions) {
            auto func_args = func.ti.operands;
            if (func_args == arg_types) {
                return func;
            }
        }
        assert (0, "doesnt do best match only perfect match :(");
    }
}

TI resolve_variable(IR ir, CTEnv env) {
    return env.typeof_(ir.name);
}
TI resolve_sequence(IR ir, CTEnv env) {
    auto res = TI.void_;
    foreach (e; ir.sequence) {
        res = e.resolve(env);
    }
    return res;
} 
TI resolve_assignment(IR ir, CTEnv env) {
    auto lhs = ir.bin.lhs.resolve(env);
    auto rhs = ir.bin.rhs.resolve(env);

    // check... O_o
    enforce(lhs == rhs);

    return lhs;
}

TI resolve_deref(IR ir, CTEnv env) {
    auto next = ir.next.resolve(env);
    enforce(next.type == TI.Type.pointer);
    return next.next;
}

TI resolve_id(IR ir, CTEnv env) {
    IR res = env.lookup(ir.name);

    assert (res.type == IR.Type.function_
            || res.type == IR.Type.variable,
            text(ir.type));
    ir.type = res.type;

    assert (res.resolved);
    return res.ti;
}

