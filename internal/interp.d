module internal.interp;

import std.stdio, std.conv;
import std.range, std.algorithm, std.array;

import internal.function_;
import internal.env, internal.val, internal.ir, internal.typeinfo;
import internal.bytecode;


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
    Val val;
    Val[] arg_stack;

    Val[] pop_args(size_t h) {
        Val[] ret = arg_stack[$-h .. h];
        arg_stack = arg_stack[0 .. $-h];
        arg_stack.assumeSafeAppend();
        return ret;
    }

    trace_msg("interpreting:");
    foreach (i, c; bc) {
        trace_msgf("%3d: %s", i, c);
    }

    while (pc < bc.length) {
        auto c = bc[pc];
        pc += 1;
        switch (c.type) {
            default: assert (0);
            case ByteCode.Type.nop:
                break;
            case ByteCode.Type.branch:
                if (!val.bool_val) {
                    pc = c.jump.target;
                }
                break;
            case ByteCode.Type.goto_:
                pc = c.jump.target;
                break;
            case ByteCode.Type.push_arg:
                arg_stack ~= val;
                break;
            case ByteCode.Type.variable_reference_lookup:
                val = Val(&env.lookup(c.var_lookup.var_name));
                break;
            case ByteCode.Type.variable_lookup:
                val = env.lookup(c.var_lookup.var_name);
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
                val = call_function(val.func, env.static_env,
                        pop_args(c.call.num_args));
                break;
            case ByteCode.Type.call_delegate:
                val = call_function(val.delegate_.func, val.delegate_.env,
                        pop_args(c.call.num_args));
                break;
            case ByteCode.Type.assignment:
                n = c.assignment.size;
                val.pointer[0 .. n] = (cast(void*)(pop_args(1).ptr))[0 ..  n];
                (cast(void*)&val)[0 .. n] = val.pointer[0 .. n];
                break;
            case ByteCode.Type.make_delegate:
                val = Val(Delegate(val.func, env));
                break;
            case ByteCode.Type.leave:
                pc = bc.length;
                break;
        }
    }

    return val;
}

Val call_function(Function f, Env env, Val[] operands) {
    auto new_env = env.extend(f.env.vars.length);
    foreach (i; 0 .. f.params.length) {
        if (f.params[i] is null) {
            continue;
        }
        auto l = f.params[i].local;
        assert (l.depth == 0);
        new_env.update(l.depth, l.index, operands[i]);
    }
    inctrace();
    auto ret = f.bc.interpret(new_env);
    dectrace();
    return ret;
}

