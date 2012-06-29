module internal.typecheck;

import std.conv, std.exception, std.stdio, std.algorithm, std.range;
import internal.typeinfo, internal.ctenv, internal.ir;

TI resolve(IR ir, CTEnv env) {
    immutable table = [
        IR.Type.if_: &resolve_if,
        IR.Type.while_: &resolve_while,
        IR.Type.nothing: &resolve_nothing,
        IR.Type.variable: &resolve_variable,
        IR.Type.constant: &resolve_constant,
        IR.Type.sequence: &resolve_sequence,
        IR.Type.application: &resolve_application,
        IR.Type.assignment: &resolve_assignment,
        IR.Type.typeid_: &resolve_typeid,
        IR.Type.addressof: &resolve_addressof,
        IR.Type.deref: &resolve_deref,
        ];

    if (ir.type in table) {
        return table[ir.type](ir, env);
    }
    assert (0, "wtf bro :D");
}

TI resolve_typeid(IR ir, CTEnv env) {
    auto next_ti = ir.next.resolve(env);

    ir.ti.type = TI.Type.class_;
    ir.ti.primitive = typeid(int[int]); // BUG
    return ir.ti;
}


TI resolve_addressof(IR ir, CTEnv env) {
    auto next_ti = ir.next.resolve(env);

    ir.ti.type = TI.Type.pointer;

    ir.ti.pointer = new TypeInfo_Pointer;
    ir.ti.pointer.m_next = next_ti.primitive;

    ir.ti.ext_data ~= next_ti;

    return ir.ti;
}

TI resolve_constant(IR ir, CTEnv env) {
    return ir.ti;
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

    enforce(condition_type == env.get_ti!bool());

    ir.while_.body_.resolve(env);

    return TI.void_;
}

TI resolve_application(IR ir, CTEnv env) {

    // TODO:
    // We need to find the overloaded function here, or something.
    // otherwise we can't really type check.

    // we assume a unary overload set here,
    // so direct type checking :-)

    TI resolve_in_env(IR ir) {
        return resolve(ir, env);
    }

    auto application = ir.application;
    auto func_type = application.operator.resolve(env);
    auto arg_types = application.operands.map!resolve_in_env().array();
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


TI resolve_variable(IR ir, CTEnv env) {
    ir.ti = env.typeof_(ir.var_name);
    return ir.ti;
}
TI resolve_sequence(IR ir, CTEnv env) {
    foreach (e; ir.sequence) {
        e.resolve(env);
    }
    return TI.void_;
} 
TI resolve_assignment(IR ir, CTEnv env) {
    auto lhs = ir.bin.lhs.resolve(env);
    auto rhs = ir.bin.rhs.resolve(env);

    // check... O_o
    enforce(lhs == rhs);

    return lhs;
}
TI resolve_nothing(IR ir, CTEnv env) {
    return TI.void_;
}

TI resolve_deref(IR ir, CTEnv env) {
    auto next = ir.next.resolve(env);
    enforce(next.type == TI.Type.pointer);
    ir.ti = next.next;
    return ir.ti;
}
