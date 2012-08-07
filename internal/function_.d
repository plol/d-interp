module internal.function_;

import internal.env;
import internal.ctenv;
import internal.ir;
import internal.typeinfo;

import stuff;

final class Function {
    CTEnv env;

    TI ti;
    bool static_;
    string name;
    string[] params;

    IR body_;

    this(CTEnv ct_env, TI ti_, bool static__, string n, string[] ps, IR b) {
        env = ct_env;
        ti = ti_;
        static_ = static__;
        name = n;
        params = ps;
        body_ = b;
    }

    string toString() {
        return name;
    }
}

struct Delegate {
    Function func;
    Env env;
}

