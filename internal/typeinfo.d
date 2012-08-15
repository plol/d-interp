module internal.typeinfo;

import std.conv, std.typetuple, std.array;


alias TypeTuple!(
        void, 
        bool,

        char,
        wchar,
        dchar,

        byte,
        ubyte,

        short,
        ushort,

        int,
        uint,

        long,
        ulong,

        //cent,
        //ucent,

        float,
        double,
        real,
        ) primitive_types;


struct TI {

    union TypeInfoUnion {
        TypeInfo_Vector vector_ = void;
        TypeInfo_Typedef typedef_ = void;
        TypeInfo_Enum enum_ = void;
        TypeInfo_Pointer pointer = void;
        TypeInfo_Array array = void;
        TypeInfo_StaticArray static_array = void;
        TypeInfo_AssociativeArray assoc_array = void;
        TypeInfo_Function function_ = void;
        TypeInfo_Delegate delegate_ = void;
        TypeInfo_Class class_ = void;
        TypeInfo_Interface interface_ = void;
        TypeInfo_Struct struct_ = void;
        TypeInfo_Tuple tuple = void;
        TypeInfo_Const const_ = void;
        TypeInfo_Invariant immutable_ = void;
        TypeInfo_Shared shared_ = void;
        TypeInfo_Inout inout_ = void;

        TypeInfo primitive = null;
    }

    enum Type {
        unresolved,
        error,
        overload_set,
        auto_,

        void_ = 99,

        bool_ = 100,

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

        const_,
        immutable_,
        inout_,
        shared_,

        builtin_function,
        builtin_delegate,
    }
    static TI void_ = TI(Type.void_);
    static TI unresolved = TI(Type.unresolved);
    static TI error = TI(Type.error);
    static TI overload_set = TI(Type.overload_set);
    static TI auto_ = TI(Type.auto_);

    Type type = Type.unresolved;
    TypeInfoUnion typeinfo;
    alias typeinfo this;

    TI[] ext_data;
    ref TI next() @property { return ext_data[0]; }
    TI next(TI new_val) @property { return ext_data[0] = new_val; }
    ref TI first() @property { return ext_data[0]; }
    ref TI second() @property { return ext_data[1]; }
    TI[] operands() @property { return ext_data[1 .. $]; }

    this(Type t, TI[] e) {
        type = t;
        ext_data = e;
    }

    bool opEquals(TI other) {
        return type == other.type
            //&& primitive == other.primitive
            && ext_data == other.ext_data;
    }

    string toString() {
        return "TI(" ~ to!string(type)
            ~ (ext_data.empty ? "" : " " ~ to!string(ext_data))
            ~ ")";
    }
}
