import std.stdio;






R each(alias fun,R)(R r) {
    foreach (ref e; r) {
        fun(e);
    }
    return r;
}
