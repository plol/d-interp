module internal.interp;

import std.stdio, std.conv;
import std.range, std.algorithm, std.array;

import internal.function_;
import internal.env, internal.val, internal.ir, internal.typeinfo;
import internal.bytecode, internal.variable;


class InterpretedException : Exception {
    this(string s, Throwable t) { super(s,t); }
    this(string s) { super(s); }
}

string lotsa_spaces = "                                                        "
~"                                                                             "
~"                                                                             "
~"                                                                             "
~"                                                                             "
~"                                                       "; // True code poetry;
int depth = 0;

bool trace = false;

void trace_msg(T...)(T t) {
    if (!trace) return;
    if (4 * depth > lotsa_spaces.length) {
        throw new InterpretedException("Stack overflow :D");
    }
    writeln(lotsa_spaces[0 .. 4*depth], t);
}
void trace_msgf(T...)(string format, T t) {
    if (!trace) return;
    write(lotsa_spaces[0 .. 4*depth]);
    writefln(format, t);
}
void dectrace() { depth -= 1; }
void inctrace() { depth += 1; }


Val interpret(ByteCode[] bc, Env env) {
    size_t pc, n;
    Val val, temp;
    Val[] arg_stack;

    Env[] env_stack;

    Val[] pop_args(size_t h) {
        Val[] ret = arg_stack[$-h .. $];
        arg_stack = arg_stack[0 .. $-h];
        arg_stack.assumeSafeAppend();
        return ret;
    }

    trace_msg("interpreting:");
    foreach (i, c; bc) {
        trace_msgf("%3x: %s", i, c);
    }

    while (pc < bc.length) {
        auto c = bc[pc];
        pc += 1;
        switch (c.type) {
            default: assert (0, text(c.type));
            case ByteCode.Type.nop:
                break;
            case ByteCode.Type.branch:
                if (!val.bool_val) {
                    pc = c.jump.target;
                }
                break;
            case ByteCode.Type.jump:
                pc = c.jump.target;
                break;
            case ByteCode.Type.push_arg:
                arg_stack ~= val;
                break;
            case ByteCode.Type.global_variable_reference_lookup:
                val = Val(&env.globals.vars[c.var_lookup.index]);
                break;
            case ByteCode.Type.global_variable_lookup:
                val = env.globals.vars[c.var_lookup.index];
                break;
            case ByteCode.Type.local_variable_reference_lookup:
                val = Val(&env.vars[c.var_lookup.index]);
                break;
            case ByteCode.Type.local_variable_lookup:
                val = env.vars[c.var_lookup.index];
                break;
            case ByteCode.Type.constant:
                val = c.constant.val;
                break;
            case ByteCode.Type.call_builtin_function:
                val = val.builtin_function(pop_args(c.call.num_args));
                break;
            case ByteCode.Type.call_builtin_delegate:
                val.builtin_delegate(pop_args(c.call.num_args));
                break;
            case ByteCode.Type.call_function:
                val = call_function(val.func, env, pop_args(c.call.num_args));
                break;
            case ByteCode.Type.call_local_function:
                val = call_local_function(val.func, env, pop_args(c.call.num_args));
                break;
            case ByteCode.Type.call_delegate:
                val = call_delegate(val.delegate_.func, val.delegate_.env,
                        pop_args(c.call.num_args));
                break;
            case ByteCode.Type.assignment:
                n = c.assignment.size;
                temp = pop_args(1)[0];
                val.pointer[0 .. n] = (cast(void*)&temp)[0 .. n];
                val = temp;
                break;
            case ByteCode.Type.make_delegate:
                val = Val(Delegate(val.func, env));
                break;

            case ByteCode.Type.push_env:
                env_stack ~= env;
                break;
            case ByteCode.Type.pop_env:
                env = env_stack.back;
                env_stack.popBack();
                env_stack.assumeSafeAppend();
                break;
            case ByteCode.Type.get_parent_env:
                env = env.parent;
                break;
            case ByteCode.Type.leave:
                pc = bc.length;
                break;
        }
    }

    return val;
}

Val call_function(Function f, Env env, Val[] operands) {
    auto new_env = new Env(f.env.var_count, env.globals);
    return call_impl(f, new_env, operands);
}

Val call_local_function(Function f, Env env, Val[] operands) {
    auto new_env = env.extend(f.env.var_count);
    return call_impl(f, new_env, operands);
}

Val call_delegate(Function f, Env env, Val[] operands) {
    auto new_env = env.extend(f.env.var_count);
    return call_impl(f, new_env, operands);
}

Val call_impl(Function f, Env env, Val[] operands) {
    size_t index;
    foreach (i; 0 .. f.params.length) {
        if (f.params[i] is null) {
            continue;
        }
        env.update(index, operands[i]);
        index += 1;
    }
    inctrace();
    auto ret = f.bc.interpret(env);
    dectrace();
    return ret;
}

