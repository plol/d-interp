module internal.function_;

import internal.env;
import internal.ctenv;
import internal.ir;
import internal.typeinfo;
import internal.bytecode;
import internal.variable;

import stuff;

final class Function {
    CTEnv env;

    TI ti;
    bool static_;
    string name;
    string[] params;

    IR body_;
    ByteCode[] bc;

    this(TI ti_, bool static__, string n, string[] ps, IR b) {
        ti = ti_;
        static_ = static__;
        name = n;
        params = ps;
        body_ = b;
    }

    override string toString() {
        return name;
    }
    bool local() @property { return !static_; }
    bool global() @property { return static_; }
}

struct Delegate {
    Function func;
    Env env;
}

