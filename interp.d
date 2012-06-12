import std.stdio;

import env, val, ir;

Val interpret(IR ir, Env env) {
    immutable table = [
        IR.Type.if_: &interpret_if,
        IR.Type.nothing: &interpret_nothing,
        IR.Type.variable: &interpret_variable,
        IR.Type.constant: &interpret_constant,
        IR.Type.sequence: &interpret_sequence,
    ];
    assert (ir.type in table, "wtf bro O_o");
    return table[ir.type](ir, env);
}

Val interpret_if(IR ir, Env env) {
    if (interpret(ir.if_.if_part, env).bool_value) {
        writeln("if_part was true!");
        interpret(ir.if_.then_part, env);
    } else {
        writeln("if_part was false!");
        interpret(ir.if_.else_part, env);
    }
    return Val.void_;
}

Val interpret_nothing(IR ir, Env env) {
    writeln("Interpreting nothing!");
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
    } else {
        // is a reference (?) :D
        assert (0);
    }
    return result;
}

