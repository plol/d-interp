

ByteCode[] generate_bytecode(IR ir, CTEnv env) {
    ByteCode[] ret;
    generate_bytecode(ir, env, ret);
    return ret;
}

size_t generate_bytecode(IR ir, CTEnv env, ref ByteCode[] bc) {
    switch (ir.type) {
        case IR.Type.if_: return generate_if(ir, env, bc);
        case IR.Type.while_: return generate_while(ir, env, bc);
        //case IR.Type.switch_: return generate_switch(ir, env, bc);
        case IR.Type.variable: return generate_variable(ir, env, bc);
        case IR.Type.sequence: return generate_sequence(ir, env, bc);
        case IR.Type.constant: return generate_constant(ir, env, bc);
        case IR.Type.application: return generate_application(ir, env, bc);
        case IR.Type.assignment: return generate_assignment(ir, env, bc);
        //case IR.Type.typeid_: return generate_typeid(ir, env, bc);
        //case IR.Type.typeof_: return generate_typeof(ir, env, bc);
        case IR.Type.addressof: return generate_addressof(ir, env, bc);
        case IR.Type.deref: return generate_deref(ir, env, bc);
        case IR.Type.return_: return generate_return(ir, env, bc);
        case IR.Type.var_decl: return generate_var_decl(ir, env, bc);
        case IR.Type.var_init: return generate_var_init(ir, env, bc);
        case IR.Type.nothing: return generate_nothing(ir, env, bc);
    }
}

size_t end(ref ByteCode[] bc) {
    return bc.length - 1;
}

size_t generate_branch(ref ByteCode[] bc) {
    bc ~= ByteCode(ByteCode.Type.branch);
}

size_t generate_jump(ref ByteCode[] bc) {
    bc ~= ByteCode(ByteCode.Type.jump);
}

size_t generate_if(IR ir, CTEnv env, ref ByteCode[] bc) {
    auto ret = ir.if_.if_part.generate_bytecode(env, bc);
    auto skip = bc.generate_branch();
    ir.if_.then_part.generate_bytecode(env, bc);
    auto jump_out = bc.generate_jump();
    auto else_start = ir.if_.else_part.generate_bytecode(env, bc);
    skip.jump_to(else_start, bc);
    jump_out.jump_to(bc.end + 1, bc);
    return ret;
}

size_t generate_while(IR ir, CTEnv env, ref ByteCode[] bc) {
    auto ret = bc.generate_jump();
    auto body_start = ir.while_.body_.generate_bytecode(env, bc);
    auto test_start = ir.while_.condition.generate_bytecode(env, bc);
    auto exit_loop = bc.generate_branch();
    auto jump_back = bc.generate_jump();

    ret.jump_to(test_start, bc);
    exit_loop.jump_to(bc.end + 1, bc);
    jump_back.jump_to(body_start, bc);
    return ret;
}

size_t generate_variable(IR ir, CTEnv env, ref ByteCode[] bc) {
    auto var = ir.variable;
    if (var.local) {
        bc ~= ByteCode(ByteCode.Type.local_variable_lookup,
                var.local.depth,
                var.local.index);
    } else if (var.global) {
        bc ~= ByteCode(ByteCode.Type.global_variable_lookup, var.global.index);
    } else {
        assert (0);
    }
}
size_t generate_sequence(IR ir, CTEnv env, ref ByteCode[] bc) {
    auto ret = bc.end + 1;
    if (ir.sequence.empty) {
        bc ~= ByteCode(ByteCode.Type.nop);
    } else {
        foreach (r; ir.sequence) {
            r.generate_bytecode(env, bc);
        }
    }
    return ret;
}

size_t generate_constant(IR ir, CTEnv env, ref ByteCode[] bc) {
    bc ~= ByteCode(ByteCode.Type.constant, ir.constant.val);
    return bc.end;
}
size_t generate_application(IR ir, CTEnv env, ref ByteCode[] bc) {
    auto ret = bc.end + 1;
    foreach (operand; ir.application.operands) {
        operand.generate_bytecode(env, bc);
        bc ~= ByteCode(ByteCode.Type.push_arg);
    }

    auto operator = ir.application.operator;
    operator.generate_bytecode(env, bc);

    auto ti = operator.ti;
    if (ti.type == TI.Type.builtin_function) {
        bc ~= ByteCode(ByteCode.type.call_builtin_delegate);
    } else if (ti.type == TI.Type.builtin_delegate) {
        bc ~= ByteCode(ByteCode.type.call_builtin_delegate);
    } else if (ti.type == TI.Type.delegate_) {
        bc ~= ByteCode(ByteCode.Type.call_delegate);
    } else if (ti.type == TI.Type.function_) {
        if (operator.function_.local) {
            bc ~= ByteCode(ByteCode.Type.call_local_function);
        } else if (operator.function_.global) {
            bc ~= ByteCode(ByteCode.Type.call_global_function);
        } else {
            assert (0);
        }
    } else {
        assert (0);
    }
    return ret;
}

size_t generate_pointer_for(IR ir, CTEnv env, ref ByteCode[] bc) {
    if (ir.type == IR.Type.variable) {
        bc ~= ByteCode(ByteCode.Type.variable_reference_lookup,
                ir.variable.depth,
                ir.variable.index);
        return bc.end;
    } else if (ir.type == IR.Type.deref) {
        return ir.next.generate_bytecode(env, bc);
    } else {
        assert (0);
    }
}


size_t generate_assignment(IR ir, CTEnv env, ref ByteCode[] bc) {
    auto ret = ir.bin.rhs.generate_bytecode(env, bc);
    bc ~= ByteCode(ByteCode.Type.push_arg);
    generate_pointer_for(ir.bin.lhs, env, bc);
    return ret;
}
size_t generate_addressof(IR ir, CTEnv env, ref ByteCode[] bc) {
    assert (0);
}
size_t generate_deref(IR ir, CTEnv env, ref ByteCode[] bc) {
    assert (0);
}
size_t generate_return(IR ir, CTEnv env, ref ByteCode[] bc) {
    auto ret = ir.next.generate_bytecode(env, bc);
    bc ~= ByteCode(ByteCode.Type.leave);
    return ret;
}
size_t generate_var_decl(IR ir, CTEnv env, ref ByteCode[] bc) {
    foreach (vi; ir.var_decl.inits) {
        vi.generate_bytecode(env, bc);
    }
}
size_t generate_var_init(IR ir, CTEnv env, ref ByteCode[] bc) {

    bc ~= ByteCode(ByteCode.Type.variable_reference_lookup,
            ir.var_init.variable.depth,
            ir.var_init.variable.index);
}
size_t generate_nothing(IR ir, CTEnv env, ref ByteCode[] bc) {
    bc ~= ByteCode(ByteCode.Type.nop);
    return bc.end;
}
