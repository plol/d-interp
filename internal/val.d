module internal.val;

import std.algorithm;
import std.array;
import std.conv;
import std.stdio;
import std.typetuple;

import internal.typeinfo;
import internal.function_;
import internal.ir;

struct Val {
    union PossibleValues {
        bool bool_val = void;
        char char_val = void;
        wchar wchar_val = void;
        dchar dchar_val = void;

        byte byte_val = void;
        ubyte ubyte_val = void;

        short short_val = void;
        ushort ushort_val = void;

        int int_val = void;
        uint uint_val = void;

        long long_val = void;
        ulong ulong_val = void;

        //cent cent_val = void;
        //ucent ucent_val = void;

        float float_val = void;
        double double_val = void;
        real real_val = void;

        void* pointer = void;
        void[] array = void;
        void* assocarray = void;
        Val delegate(Val[]) builtin_delegate;
        Val function(Val[]) builtin_function;
        Delegate delegate_;
        Function func;
    }

    static enum Val void_ = Val();

    PossibleValues tagged_union;
    alias tagged_union this;

    this(Val delegate(Val[]) operator) { builtin_delegate = operator; }
    this(Val function(Val[]) operator) { builtin_function = operator; }
    this(void* p) { pointer = p; }
    this(Object p) { pointer = cast(void*)p; }
    this(char c) { char_val = c; }
    this(bool b) { bool_val = b; }
    this(int b) { int_val = b; }
    this(ulong u) { ulong_val = u; }
    this(float f) { float_val = f; }
    this(double f) { double_val = f; }
    this(real f) { real_val = f; }
    this(Delegate d) { tagged_union.delegate_ = d; }
    this(Function d) { tagged_union.func = d; }
    this(const void[] a) { tagged_union.array = cast(void[])a; }

    string toString() const {
        return "Val()";
    }
    string toString(TI ti) {
        auto type = ti.type;
        switch (type) {
            default: return text("Val(", type, ")");
            case TI.Type.void_: return "Val(void)";
            foreach (T; TypeTuple!(bool, char, wchar, dchar, byte, ubyte, short, ushort,
                        int, uint, long, ulong, float, double, real)) {
                mixin ("case TI.Type."~T.stringof~"_:
                        return \""~T.stringof~" \"~to!string("~T.stringof~"_val);");
            }
            case TI.Type.assocarray:
                                return to!string(*cast(int[int]*)&pointer);
            case TI.Type.array:
                if (ti.next.type == TI.Type.char_) {
                    return "\""~cast(string)tagged_union.array~"\"";
                } else {
                    return format_array(tagged_union.array, ti.next);
                }
        }
    }
}


string format_array(void[] array, TI elementtype) {
    assert (0);
}
