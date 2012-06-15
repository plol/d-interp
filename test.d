import std.stdio;

import ir, env, interp, val;

void main() {
    auto env = new Env();

    env.declare("a", Val(1));
    env.declare("b", Val(2));

    writeln(interpret(
                new IR(IR.Type.sequence, [
                    new IR(IR.Type.if_, 
                        new IR(IR.Type.constant, Val(false)),
                        new IR(IR.Type.nothing),
                        new IR(IR.Type.variable, "a")),
                    new IR(IR.Type.if_, 
                        new IR(IR.Type.constant, Val(true)),
                        new IR(IR.Type.application,
                            new IR(IR.Type.variable, "$add_int"),
                            [
                            new IR(IR.Type.variable, "a"),
                            new IR(IR.Type.variable, "b"),
                            ]),
                        new IR(IR.Type.nothing)),
                    ]), env));
}
