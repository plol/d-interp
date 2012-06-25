import std.stdio;
import std.algorithm;
import std.array;
import std.conv;

import typeinfo;

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

    string toString() const {
        return "Val()";
    }
    string toString(TI ti) {
        auto type = ti.type;
        switch (type) {
            default: return text("Val(", type, ")");
            case TI.Type.void_: return "no value produced";
            case TI.Type.bool_: return to!string(bool_val);
            case TI.Type.int_: return to!string(int_val);
            case TI.Type.char_: return "'"~to!string(char_val)~"'";
            case TI.Type.assocarray:
                                return to!string(*cast(int[int]*)&pointer);
        }
    }
}

