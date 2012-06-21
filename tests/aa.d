import std.stdio;

struct S {
    int a;
}

extern (C) void* _aaGetX(void* aa, TypeInfo keyti, size_t valuesize, void* pkey);
extern (C) void* _aaGetRvalueX(void* aa, TypeInfo keyti, size_t valuesize, void* pkey);

void main() {
    int[S] aa;
    S s;
    s.a = 4;
    *cast(int*)_aaGetX(cast(void*)&aa, typeid(S), int.sizeof, &s) = 4;
    writeln(*cast(int*)_aaGetRvalueX(cast(void*)aa, typeid(S), int.sizeof, &s));


}
