import std.stdio;
import std.range, std.algorithm, std.array;

import env, val, ir, typeinfo;

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
    ];
    assert (ir.type in table, "wtf bro O_o");
    return table[ir.type](ir, env);
}

Val interpret_if(IR ir, Env env) {
    if (interpret(ir.if_.if_part, env).bool_val) {
        writeln("if_part was true!");
        interpret(ir.if_.then_part, env);
    } else {
        writeln("if_part was false!");
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
    writeln("Interpreting nothing!");
    return Val.void_;
}

Val interpret_constant(IR ir, Env env) {
    return ir.val;
}

Val interpret_variable(IR ir, Env env) {
    writeln("looking up variable ", ir.var_name, " = ",
            env.lookup(ir.var_name).toString(ir.ti));
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

