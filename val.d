import std.stdio;

struct Val {
    static immutable Val void_;

    this(bool b) {
    }

    bool bool_value() @property const {
        return true;
    }
}
