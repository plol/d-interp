module internal.ast2ir;

import std.stdio, std.conv;

import internal.ast, internal.ir;
import internal.typeinfo;
import internal.ctenv;
import internal.function_;
import internal.variable;
import lexer;

IR toIR(Ast ast, CTEnv env) {

    assert (ast !is null);

    IR[] wtf;

    switch (ast.type) {
        default: assert (0, text(ast.type, " ", ast));
        case Ast.Type.vardecl:
                 {
                     foreach (v; ast.bin.rhs.var_init_list.vars) {
                         auto var = new Variable(v.var_init.name);
                         wtf ~= new IR(IR.Type.var_init, var,
                                 v.var_init.initializer.toIR(env));
                     }
                     return new IR(IR.Type.var_decl,
                             ti_from_ast(env, ast.bin.lhs), wtf);
                 }
        case Ast.Type.funcdef: 
                 {
                     auto func = get_function(ast, env);
                     return new IR(IR.Type.function_, func.ti, func);
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
        case Ast.Type.return_: return ir.return_(ast.next.toIR(env));
        case Ast.Type.prefix:
                               assert (ast.bin.lhs.type == Ast.Type.prefix_op);
                               assert (ast.bin.lhs.str == "&");
                               return ir.addressof(ast.bin.rhs.toIR(env));
    }
}

Function get_function(Ast ast, CTEnv env) {
    TI return_type = ti_from_ast(env, ast.funcdef.return_type);

    TI[] type_data = [return_type];
    string[] parameter_names;

    foreach (param; ast.funcdef.params.parameter_list.params) {
        type_data ~= ti_from_ast(env, param.type);
        parameter_names ~= param.name;
    }

    Variable[] params;
    foreach (i; 0 .. parameter_names.length) {
        auto p = new Variable(parameter_names[i]);
        p.ti = type_data[i+1];
        params ~= p;

    }

    IR body_ = ast.funcdef.body_.toIR(env);
    assert (body_.type == IR.Type.sequence);
    return new Function( 
                TI(TI.Type.function_, type_data),
                env.parent is null,
                ast.funcdef.name, params, body_);
}


TI ti_from_ast(CTEnv env, Ast type) {
    assert (type.typedata.mod.type == TypeMod.Type.nothing, text(type));
    auto real_type = type.typedata.ast;
    assert (real_type.type == Ast.Type.basic_type, text(type));
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
