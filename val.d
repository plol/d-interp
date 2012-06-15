import std.stdio;
import std.algorithm;
import std.array;
import std.conv;

struct Val {
    enum Type {
        void_,

        bool_,

        char_,
        wchar_,
        dchar_,

        byte_,
        ubyte_,

        short_,
        ushort_,

        int_,
        uint_,

        long_,
        ulong_,

        cent_,
        ucent_,

        float_,
        double_,
        real_,

        class_,
        interface_,
        struct_,
        enum_,
        union_,

        pointer,
        array,
        assocarray,

        delegate_,
        function_,

        builtin_function,
        builtin_delegate,
    }

    static Val void_ = Val(Type.void_);

    Type type;

    union {
        bool bool_val = void;
        int int_val = void;
        char char_val = void;
        Val* pointer = void;
        Val[] array = void;
        Val[Val] assocarray = void;
        Val delegate(Val[]) builtin_delegate;
    }

    this(string s) {
        type = Type.array;
        array = std.array.array(map!Val(s));
    }

    this(Val delegate(Val[]) operator) {
        type = Type.builtin_delegate;
        builtin_delegate = operator;
    }

    this(char c) {
        type = Type.char_;
        char_val = c;
    }

    this(int b) {
        type = Type.int_;
        int_val = b;
    }
    this(bool b) {
        type = Type.bool_;
        bool_val = b;
    }

    bool bool_value() @property const {
        assert (type == Type.bool_);
        return bool_val;
    }

    Val apply(Val[] operands) {
        if (type == Type.builtin_delegate) {
            return builtin_delegate(operands);
        } else {
            assert (0);
        }
    }








    string toString() const {
        switch (type) {
            default: return text("Val(", type, ")");
            case Type.bool_: return to!string(bool_val);
            case Type.int_: return to!string(int_val);
            case Type.char_: return "'"~to!string(char_val)~"'";
            case Type.array: return to!string(array);
            case Type.assocarray: return to!string(assocarray);
        }
    }
}

