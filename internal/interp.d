module internal.interp;

import std.stdio, std.conv;
import std.range, std.algorithm, std.array;

import internal.env, internal.val, internal.ir, internal.typeinfo;

Val interpret(IR ir, Env env) {
    immutable table = [
        IR.Type.if_: &interpret_if,
        IR.Type.while_: &interpret_while,
        IR.Type.nothing: &interpret_nothing,
        IR.Type.variable: &interpret_variable,
        IR.Type.constant: &interpret_constant,
        IR.Type.sequence: &interpret_sequence,
        IR.Type.application: &interpret_application,
        IR.Type.assignment: &interpret_assignment,
        IR.Type.typeid_: &interpret_typeid,
        IR.Type.addressof: &interpret_addressof,
    ];
    assert (ir.type in table, text("wtf bro O_o ", ir.type));
    return table[ir.type](ir, env);
}

Val interpret_if(IR ir, Env env) {
    if (interpret(ir.if_.if_part, env).bool_val) {
        interpret(ir.if_.then_part, env);
    } else {
        interpret(ir.if_.else_part, env);
    }
    return Val.void_;
}
Val interpret_while(IR ir, Env env) {
    while (interpret(ir.while_.condition, env).bool_val) {
        interpret(ir.while_.body_, env);
    } 
    return Val.void_;
}

Val interpret_nothing(IR ir, Env env) {
    return Val.void_;
}

Val interpret_constant(IR ir, Env env) {
    return ir.val;
}

Val interpret_variable(IR ir, Env env) {
    return env.lookup(ir.var_name);
}

Val interpret_sequence(IR ir, Env env) {
    foreach (c; ir.sequence) {
        interpret(c, env);
    }
    return Val.void_;
}

Val interpret_assignment(IR ir, Env env) {
    auto result = interpret(ir.bin.rhs, env);
    if (ir.bin.lhs.type == IR.Type.variable) {
        env.update(ir.bin.lhs.var_name, result);
    } else if (ir.bin.lhs.type == IR.Type.deref) {
        auto ptr = interpret(ir.bin.lhs.next, env);
        auto size = ir.bin.lhs.ti.primitive.tsize();

        auto rhs = interpret(ir.bin.rhs, env);
        
        ptr.pointer[0 .. size] = (cast(void*)(&rhs.tagged_union))[0 .. size];
    } else {
        // is a reference (?) :D
        assert (0);
    }
    return result;
}

Val interpret_application(IR ir, Env env) {
    Val interpret_in_env(IR o) {
        return interpret(o, env);
    }
    Val operator = interpret(ir.application.operator, env);
    Val[] operands = map!interpret_in_env(ir.application.operands).array();

    Val res;
    if (ir.application.operator.ti.type == TI.Type.builtin_delegate) {
        res = operator.builtin_delegate(operands);
    } else if (ir.application.operator.ti.type == TI.Type.builtin_function) {
        res = operator.builtin_function(operands);
    } else {
        assert (0);
    }

    return res;
}

Val interpret_typeid(IR ir, Env env) {
    if (ir.next.ti.type == TI.Type.int_) {
        return Val(typeid(int));
    } else {
        assert (0, text(ir.next.ti.type));
    }
}

Val interpret_addressof(IR ir, Env env) {
    auto res = Val(&env.lookup(ir.next.var_name));
    return res;
}
