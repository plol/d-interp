module internal.interp;

import std.stdio, std.conv;
import std.range, std.algorithm, std.array;

import internal.function_;
import internal.env, internal.val, internal.ir, internal.typeinfo;


class InterpretedException : Exception {
    this(string s, Throwable t) { super(s,t); }
    this(string s) { super(s); }
}

struct Cont {
    GotoCont goto_;
    GotoCaseCont goto_case;
    GotoStringCaseCont goto_string_case;
    ReturnCont return_;
    FailCont fail;
    SucceedCont succeed;

    Cont with_succeed(SucceedCont s) {
        auto ret = this;
        ret.succeed = s;
        return ret;
    }
    Cont with_fail(FailCont f) {
        auto ret = this;
        ret.fail = f;
        return ret;
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

void pre_interpret(IR ir) {
    if (!trace) return;
    writeln(lotsa_spaces[0 .. depth], "pre interpret: ", ir);
    depth += 2;
}
void post_interpret(IR ir, Val val) {
    if (!trace) return;
    depth -= 2;
    writeln(lotsa_spaces[0 .. depth], "resulting val: ", val.toString(ir.ti));
}
    
void interpret(IR ir, Env env, Cont cont) {
    immutable table = [
        IR.Type.if_: &interpret_if,
        IR.Type.while_: &interpret_while,
        IR.Type.nothing: &interpret_nothing,
        IR.Type.variable: &interpret_variable,
        IR.Type.constant: &interpret_constant,
        IR.Type.sequence: &interpret_sequence,
        IR.Type.application: &interpret_application,
        IR.Type.assignment: &interpret_assignment,
        IR.Type.addressof: &interpret_addressof,
        IR.Type.deref: &interpret_deref,
        IR.Type.delegate_instantiation: &interpret_delegate_instantiation,
        IR.Type.local_function_create: &interpret_local_function_create,
    ];
    assert (ir.type in table, text("wtf bro O_o ", ir.type));
    pre_interpret(ir);
    return table[ir.type](ir, env, cont.with_succeed((Val ret, FailCont fail) {
        post_interpret(ir, ret);
        return cont.succeed(ret, fail);
    }));
}

void interpret_if(IR ir, Env env, Cont cont) {
    return interpret(ir.if_.if_part, env, cont.with_succeed(
                (Val result, FailCont fail) {
        if (result.bool_val) {
            return interpret(ir.if_.then_part, env, cont.with_fail(fail));
        } else {
            return interpret(ir.if_.else_part, env, cont.with_fail(fail));
        }
    }));
}
void interpret_while(IR ir, Env env, Cont cont) {
    interpret(ir.while_.condition, env,
            cont.with_succeed((Val result, FailCont fail) {
        if (result.bool_val) {
            return interpret(ir.while_.body_, env, cont.with_fail(fail)
                .with_succeed((Val ignored, FailCont fail2) {
                return interpret_while(ir, env, cont.with_fail(fail2));
            }));
        } else {
            return cont.succeed(Val.void_, cont.fail);
        }
    }));
}

void interpret_nothing(IR ir, Env env, Cont cont) {
    return cont.succeed(Val.void_, cont.fail);
}

void interpret_constant(IR ir, Env env, Cont cont) {
    return cont.succeed(ir.constant.val, cont.fail);
}

void interpret_variable(IR ir, Env env, Cont cont) {
    return cont.succeed(env.lookup(ir.variable.name), cont.fail);
}

void interpret_sequence(IR ir, Env env, Cont cont) {

    void do_all(IR[] sequence, Val val, FailCont fail) {
        if (sequence.empty) {
            cont.succeed(val, fail);
        } else {
            sequence[0].interpret(env, cont.with_succeed(
                        (Val v, FailCont fail2) {
                do_all(sequence[1 .. $], v, fail2);
            }));
        }
    }
    return do_all(ir.sequence, Val.void_, cont.fail);
}

void interpret_assignment(IR ir, Env env, Cont cont) {
    interpret(ir.bin.rhs, env, cont.with_succeed((Val result, FailCont fail) {
        if (ir.bin.lhs.type == IR.Type.variable) { // Get rid of this if() :/
            env.update(ir.bin.lhs.variable.name, result);
            return cont.succeed(result, cont.fail);
        } else if (ir.bin.lhs.type == IR.Type.deref) {
            return interpret(ir.bin.lhs.next, env, cont.with_succeed(
                    (Val ptr, FailCont fail2) {

                auto size = ir.bin.lhs.ti.primitive.tsize();
                void* rhs_ptr = cast(void*)&result.tagged_union;
                ptr.pointer[0 .. size] = rhs_ptr[0 .. size];
                return cont.succeed(result, fail2);
            }));
        } else {
            assert (0);
        }
    }));
}

void interpret_application(IR ir, Env env, Cont cont) {
    return interpret(ir.application.operator, env, cont.with_succeed(
                (Val operator, FailCont fail) {

        void function_call_dispatch(Val[] operands, FailCont fail4) {
            auto cont2 = cont.with_fail(fail4);
            switch (ir.application.operator.ti.type) {
                case TI.Type.builtin_delegate:
                    return cont.succeed(operator.builtin_delegate(operands), fail4);
                case TI.Type.builtin_function:
                    return cont.succeed(operator.builtin_function(operands), fail4);
                case TI.Type.delegate_:
                    {
                        auto dg = operator.delegate_;
                        return call_function(dg.func, dg.env, cont2, operands);
                    }
                case TI.Type.function_:
                    return call_function(operator.func, env.static_env,
                        cont2, operands);
                default:
                    assert (0, text(ir.application.operator.ti.type));
            }
        }

        void get_operands(IR[] operand_irs, Val[] operands, FailCont fail2) {
            if (operand_irs.empty) {
                return function_call_dispatch(operands, fail2);
            } else {
                return interpret(operand_irs[0], env, cont.with_fail(fail)
                        .with_succeed((Val op, FailCont fail3) {
                    operands ~= op;
                    get_operands(operand_irs[1 .. $], operands, fail3);
                }));
            }
        }

        return get_operands(ir.application.operands, [], fail);
    }));
}

void call_function(Function f, Env env, Cont cont, Val[] operands) {
    auto new_env = env.extend();
    foreach (var; f.env.vars) {
        new_env.declare(var.variable.name, var.variable.val);
    }
    foreach (func; f.env.local_funcs) {
        new_env.declare(func.get_name(), Val());
    }
    foreach (i; 0 .. f.params.length) {
        if (f.params[i].empty) {
            continue;
        }
        new_env.update(f.params[i], operands[i]);
    }
    return f.body_.interpret(new_env, cont);
}

void interpret_addressof(IR ir, Env env, Cont cont) {
    if (ir.next.type == IR.Type.variable) {
        return cont.succeed(Val(&env.lookup(ir.next.variable.name)), cont.fail);
    } else {
        assert (0);
    }
}

void interpret_deref(IR ir, Env env, Cont cont) {
    assert (ir.next.ti.type == TI.Type.pointer);

    return ir.next.interpret(env, cont.with_succeed((Val ptr, FailCont fail) {
        Val ret;
        auto size = ir.bin.lhs.ti.primitive.tsize();
        (cast(void*)(&ret.tagged_union))[0 .. size] = ptr.pointer[0 .. size];
        return cont.succeed(ret, fail);
    }));
}

void interpret_delegate_instantiation(IR ir, Env env, Cont cont) {
    return cont.succeed(Val(Delegate(ir.function_, env)), cont.fail);
}

void interpret_local_function_create(IR ir, Env env, Cont cont) {
    env.update(ir.function_.name, Val(Delegate(ir.function_, env)));
    return cont.succeed(Val.void_, cont.fail);
}

