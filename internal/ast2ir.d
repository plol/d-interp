module internal.ast2ir;

import std.stdio, std.conv;

import internal.ast, internal.ir;
import internal.typeinfo;
import internal.ctenv;
import internal.function_;
import lexer;

IR toIR(Ast ast, CTEnv env) {

    assert (ast !is null);

    IR[] wtf;

    switch (ast.type) {
        default: assert (0, text(ast.type, " ", ast));
        case Ast.Type.vardecl:
                 declare_vars(env, ast.bin.lhs, ast.bin.rhs.id_list);
                 return null;

        case Ast.Type.funcdef:
                 {
                     auto func = get_function(ast, env);
                     if (func.static_) {
                         env.func_declare(func);
                         return null;
                     } else {
                         env.local_func_declare(func);
                         return new IR(IR.Type.local_function_create, func);
                     }
                 }
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
        case Ast.Type.sequence: 
                      foreach (a; ast.sequence) {
                          auto r = a.toIR(env);
                          if (r !is null) {
                              wtf ~= r;
                          }
                      }
                      return ir.seq(wtf);

        case Ast.Type.int_: return ir.constant(env, to!int(ast.ulong_val));
        case Ast.Type.uint_: return ir.constant(env, to!uint(ast.ulong_val));
        case Ast.Type.long_: return ir.constant(env, to!long(ast.ulong_val));
        case Ast.Type.ulong_: return ir.constant(env, ast.ulong_val);

        case Ast.Type.float_: return ir.constant(env, to!float(ast.real_val));
        case Ast.Type.double_: return ir.constant(env, to!double(ast.real_val));
        case Ast.Type.real_: return ir.constant(env, ast.real_val);

        case Ast.Type.string_: return ir.constant(env, ast.str);
        case Ast.Type.wstring_: return ir.constant(env, ast.wstr);
        case Ast.Type.dstring_: return ir.constant(env, ast.dstr);

        case Ast.Type.assignment: return ir.set(
                                      ast.bin.lhs.toIR(env),
                                      ast.bin.rhs.toIR(env));
        case Ast.Type.binop: return ir.call(
                                 ir.id(opfuncname(ast.binop.op)),
                                 ast.binop.lhs.toIR(env),
                                 ast.binop.rhs.toIR(env));
        case Ast.Type.application:
                             foreach (arg; ast.bin.rhs.arg_list) {
                                 wtf ~= arg.toIR(env);
                             }
                             return ir.call(ast.bin.lhs.toIR(env), wtf);
    }
}

Function get_function(Ast ast, CTEnv env) {
    TI[] type_data;
    TI return_type = ti_from_ast(env, ast.funcdef.return_type);
    type_data ~= return_type;

    string name = ast.funcdef.name;

    string[] parameter_names;
    foreach (param; ast.funcdef.params.parameter_list.params) {
        type_data ~= ti_from_ast(env, param.type);
        parameter_names ~= param.name;
    }
    auto new_env = env.extend(type_data[1..$], parameter_names);
    IR body_ = ast.funcdef.body_.toIR(new_env);
    assert (body_.type == IR.Type.sequence);
    return new Function(new_env, 
                TI(env.parent is null ? TI.Type.function_ : TI.Type.delegate_, type_data),
                env.parent is null,
                name, parameter_names, body_);
}

void declare_vars(CTEnv env, Ast type, Token[] ids) {
    auto ti = ti_from_ast(env, type);
    foreach (id; ids) {
        env.var_declare(ti, id.str);
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
        case ">": return "$gt";
        case "^": return "$xor";
        case "&": return "$and";
        case "^^": return "$pow";
        default: assert (0, "no opfuncname for " ~ op);
    }
}
