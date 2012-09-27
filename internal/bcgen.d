module internal.bcgen;

import std.array;
import std.stdio;
import std.conv;

import internal.bytecode;
import internal.ctenv;
import internal.ir;
import internal.typeinfo;
import internal.val;

ByteCode[] generate_bytecode(IR ir, CTEnv env) {
    ByteCode[] ret;
    generate_bytecode(ir, env, ret);
    return ret;
}

size_t generate_bytecode(IR ir, CTEnv env, ref ByteCode[] bc) {
    switch (ir.type) {
        default: assert (0, text(ir.type));
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
        case IR.Type.function_: return generate_function(ir, env, bc);
        case IR.Type.up_ref: return generate_up_ref(ir, env, bc);
        case IR.Type.nothing: return generate_nothing(ir, env, bc);
    }
}

size_t end(ref ByteCode[] bc) {
    return bc.length - 1;
}

void jump_to(size_t a, size_t b, ref ByteCode[] bc) {
    bc[a].jump.target = b;
}

size_t generate_branch(ref ByteCode[] bc) {
    bc ~= ByteCode(ByteCode.Type.branch);
    return bc.end;
}

size_t generate_jump(ref ByteCode[] bc) {
    bc ~= ByteCode(ByteCode.Type.jump);
    return bc.end;
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

IR unwind_up_ref(IR ir, ref ByteCode[] bc) {
    while (ir.type == IR.Type.up_ref) {
        bc ~= ByteCode(ByteCode.Type.get_parent_env);
        ir = ir.next;
    }
    return ir;
}

size_t generate_up_ref(IR ir, CTEnv env, ref ByteCode[] bc) {
    auto ret = bc.end + 1;
    bc ~= ByteCode(ByteCode.Type.push_env);
    auto inner = unwind_up_ref(ir, bc);
    inner.generate_bytecode(env, bc);
    bc ~= ByteCode(ByteCode.Type.pop_env);
    return ret;
}

size_t generate_variable(IR ir, CTEnv env, ref ByteCode[] bc) {
    auto var = ir.variable;
    if (var.local) {
        bc ~= ByteCode(ByteCode.Type.local_variable_lookup, var.index);
        return bc.end;
    } else if (var.global) {
        bc ~= ByteCode(ByteCode.Type.global_variable_lookup, var.index);
        return bc.end;
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
    auto ret = bc.end;

    if (ir.ti.type == TI.Type.delegate_) {
        bc ~= ByteCode(ByteCode.Type.make_delegate);
    }

    return ret;
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
    auto argc = ti.operands.length;

    void append_call_bytecode(TI ti) {
        if (ti.type == TI.Type.builtin_function) {
            bc ~= ByteCode(ByteCode.Type.call_builtin_function, argc);
        } else if (ti.type == TI.Type.builtin_delegate) {
            bc ~= ByteCode(ByteCode.Type.call_builtin_delegate, argc);
        } else if (ti.type == TI.Type.delegate_) {
            bc ~= ByteCode(ByteCode.Type.call_delegate, argc);
        } else if (ti.type == TI.Type.function_) {
            bc ~= ByteCode(ByteCode.Type.call_function, argc);
        } else if (ti.type == TI.Type.local_function) {
            bc ~= ByteCode(ByteCode.Type.call_local_function, argc);
        } else if (ti.type == TI.Type.pointer) {
            append_call_bytecode(ti.next);
        } else {
            assert (0);
        }
    }
    append_call_bytecode(ti);
    return ret;
}

size_t generate_pointer_for(IR ir, CTEnv env, ref ByteCode[] bc) {
    if (ir.type == IR.Type.variable) {
        auto bctype = ir.variable.local 
            ? ByteCode.Type.local_variable_reference_lookup
            : ByteCode.Type.global_variable_reference_lookup;
        bc ~= ByteCode(bctype, ir.variable.index);
        return bc.end;
    } else if (ir.type == IR.Type.deref) {
        return ir.next.generate_bytecode(env, bc);
    } else if (ir.type == IR.Type.up_ref) {
        auto ret = bc.end + 1;
        bc ~= ByteCode(ByteCode.Type.push_env);
        auto inner = unwind_up_ref(ir, bc);
        generate_pointer_for(inner, env, bc);
        bc ~= ByteCode(ByteCode.Type.pop_env);
        return ret;
    } else {
        assert (0);
    }
}


size_t generate_assignment(IR ir, CTEnv env, ref ByteCode[] bc) {
    auto ret = ir.bin.rhs.generate_bytecode(env, bc);
    bc ~= ByteCode(ByteCode.Type.push_arg);
    generate_pointer_for(ir.bin.lhs, env, bc);
    bc ~= ByteCode(ByteCode.Type.assignment, ir.ti.tsize());
    return ret;
}
size_t generate_addressof(IR ir, CTEnv env, ref ByteCode[] bc) {
    if (ir.next.type == IR.Type.constant) {
        assert (0);
    }
    return generate_pointer_for(ir.next, env, bc);
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
    auto ret = bc.end+1;
    foreach (vi; ir.var_decl.inits) {
        vi.generate_bytecode(env, bc);
    }
    return ret;
}
size_t generate_var_init(IR ir, CTEnv env, ref ByteCode[] bc) {
    auto var_init = ir.var_init;
    writeln(env.table);
    assert (env.lookup(var_init.name).type == IR.Type.variable);
    auto var_ir = env.lookup(var_init.name);
    auto var = var_ir.variable;

    if (var.global) {
        return var_ir.generate_bytecode(env, bc);
    }

    size_t ret;

    if (var_init.initializer.type == IR.Type.nothing) {
        bc ~= ByteCode(ByteCode.Type.constant, init_val(ir.ti));
        ret = bc.end;
    } else {
        ret = var_init.initializer.generate_bytecode(env, bc);
    }
    bc ~= ByteCode(ByteCode.Type.push_arg);
    generate_pointer_for(var_ir, env, bc);
    bc ~= ByteCode(ByteCode.Type.assignment, ir.ti.tsize());
    return ret;
}
size_t generate_nothing(IR ir, CTEnv env, ref ByteCode[] bc) {
    bc ~= ByteCode(ByteCode.Type.nop);
    return bc.end;
}

size_t generate_function(IR ir, CTEnv env, ref ByteCode[] bc) {
    bc ~= ByteCode(ByteCode.Type.nop);
    auto ret = bc.end;

    ir.function_.body_.generate_bytecode(ir.function_.env, ir.function_.bc);

    return ret;
}
