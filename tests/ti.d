import std.stdio;

class C {
    int x;
    int[2012] y;
}

void main() {
    writeln(typeid(C).tsize);
}

