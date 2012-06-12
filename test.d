import std.stdio;

import ir, env, interp, val;

void main() {
    auto env = new Env();

    env.declare("a", Val(true));

    writeln(interpret(
                new IR(IR.Type.sequence, [
                    new IR(IR.Type.if_, 
                        new IR(IR.Type.constant, Val(true)),
                        new IR(IR.Type.nothing),
                        new IR(IR.Type.nothing)),
                    new IR(IR.Type.if_, 
                        new IR(IR.Type.constant, Val(true)),
                        new IR(IR.Type.variable, "a"),
                        new IR(IR.Type.nothing)),
                    ]), env));
}
