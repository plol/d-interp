module internal.bytecode;

import internal.val;
import internal.typeinfo;
import internal.variable;

struct ByteCode {
    enum Type {
        nop,
        branch,
        jump,
        goto_,
        push_arg,
        local_variable_reference_lookup,
        local_variable_lookup,
        global_variable_reference_lookup,
        global_variable_lookup,
        constant,
        call_builtin_function,
        call_builtin_delegate,
        call_function,
        call_delegate,
        call_local_function,
        assignment,
        make_delegate,
        leave,
    }
    static struct Jump {
        size_t target;
    }
    static struct VarLookup {
        size_t depth;
        size_t index;
    }
    static struct Constant {
        Val val;
    }
    static struct Call {
        size_t num_args;
    }
    static struct Assignment {
        size_t size;
    }

    union PossibleValues {
        Jump jump;
        VarLookup var_lookup;
        Constant constant;
        Call call;
        Assignment assignment;
    }

    Type type;
    PossibleValues values;
    alias values this;

    this(Type t) {
        type = t;
        jump = Jump();
    }
    this(Type t, Val val) {
        type = t;
        if (t == Type.constant) {
            constant = Constant(val);
        } else {
            assert (0);
        }
    }
    this(Type t, size_t index) {
        type = t;
        if (t == Type.global_variable_lookup) {
            var_lookup = VarLookup(0, index);
        } else if (t == Type.global_variable_reference_lookup) {
            var_lookup = VarLookup(0, index);
        } else {
            assert (0);
        }
    }
    this(Type t, RelativeVarIndex rel) {
        type = t;
        if (t == Type.local_variable_lookup) {
            var_lookup = VarLookup(rel.depth, rel.index);
        } else if (t == Type.local_variable_reference_lookup) {
            var_lookup = VarLookup(rel.depth, rel.index);
        } else {
            assert (0);
        }
    }
}


