import std.stdio, std.traits;


alias int function(int) h;
void main() {

    writeln(typeid(h));
}
