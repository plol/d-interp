import std.conv;

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

        TypeInfo primitive = void;
    }

    enum Type {
        void_ = 0,

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

        builtin_function,
        builtin_delegate,
    }
    static TI void_ = TI();

    Type type = Type.void_;
    TypeInfoUnion typeinfo;
    alias typeinfo this;

    // [return_type, parameters...]
    TI[] func_data;
}
