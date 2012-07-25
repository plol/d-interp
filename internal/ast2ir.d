module internal.ast2ir;

import std.stdio, std.conv;

import internal.ast, internal.ir;
import internal.typeinfo;
import internal.ctenv;
import lexer;

IR toIR(Ast ast, CTEnv env) {

    assert (ast !is null);

    IR[] wtf;

    switch (ast.type) {
        default: assert (0);
        case Ast.Type.vardecl:
                 declare_vars(env, ast.bin.lhs, ast.bin.rhs.id_list);
                 return null;


        case Ast.Type.nothing: return ir.nothing();
        case Ast.Type.if_: return ir.if_(
                               ast.if_.if_part.toIR(env),
                               ast.if_.then_part.toIR(env),
                               ast.if_.else_part.toIR(env));
        case Ast.Type.while_: return ir.while_(
                                  ast.while_.condition.toIR(env),
                                  ast.while_.body_.toIR(env));
        case Ast.Type.statement: return ast.next.toIR(env);

        case Ast.Type.id: return ir.id(ast.str);
                      //case Type.sequence: return ir.seq(values.sequence
                      //                            .map!toIR_env().array());
        case Ast.Type.sequence: 
                      foreach (a; ast.sequence) {
                          wtf ~= a.toIR(env);
                      }
                      return ir.seq(wtf);

        case Ast.Type.int_: return ir.constant(env, to!int(ast.ulong_val));
        case Ast.Type.uint_: return ir.constant(env, to!uint(ast.ulong_val));
        case Ast.Type.long_: return ir.constant(env, to!long(ast.ulong_val));
        case Ast.Type.ulong_: return ir.constant(env, ast.ulong_val);

        case Ast.Type.float_: return ir.constant(env, to!float(ast.real_val));
        case Ast.Type.double_: return ir.constant(env, to!double(ast.real_val));
        case Ast.Type.real_: return ir.constant(env, ast.real_val);

        case Ast.Type.assignment: return ir.set(
                                      ast.bin.lhs.toIR(env),
                                      ast.bin.rhs.toIR(env));
        case Ast.Type.binop: return ir.call(
                                 ir.id(opfuncname(ast.binop.op)),
                                 ast.binop.lhs.toIR(env),
                                 ast.binop.rhs.toIR(env));
    }
}

void declare_vars(CTEnv env, Ast type, Token[] ids) {
    auto ti = ti_from_ast(env, type);
    foreach (id; ids) {
        env.declare(ti, id.str);
    }
}

TI ti_from_ast(CTEnv env, Ast type) {
    assert (type.typedata.mod.type == TypeMod.Type.nothing);
    auto real_type = type.typedata.ast;
    assert (real_type.type == Ast.Type.basic_type);
    return env.get_basic_ti(real_type.ti_type);
}

string opfuncname(string op) {
    switch (op) {
        case "+": return "$add";
        case "-": return "$sub";
        case "*": return "$mul";
        case "/": return "$div";
        case "<": return "$lt";
        default: assert (0, "no opfuncname for " ~ op);
    }
}
