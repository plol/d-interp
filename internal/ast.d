module internal.ast;

import std.array, std.string, std.algorithm, std.range, std.conv;
import std.exception, std.stdio, std.typecons;

import internal.ir;
alias internal.ir ir;

import internal.ctenv;
import lexer;
import stuff;

alias stuff.format format;

struct Operator {
    enum Type {
        prefix,
        postfix,
        binary,
    }
    Type type;
    string ast;
}

final class Ast {
    static enum Type {
        if_,
        while_,
        switch_,
        for_,
        foreach_,

        funcdef,
        classdef,
        structdef,
        enumdef,

        vardecl,

        statement,

        id,
        sequence,

        application,

        assignment,

        typeid_,
        typeof_,

        addressof,
        deref,

        member_lookup,

        bool_,
        dchar_,
        int_,
        uint_,
        long_,
        ulong_,
        float_,
        double_,
        real_,
        string_,
        wstring_,
        dstring_,

        array,
        assocarray,

        binop,
        postfix,
        prefix,

        other,
    }

    static struct While {
        Ast condition, body_;
    }
    static struct If {
        Ast if_part, then_part, else_part;
    }
    static struct Binop {
        string op;
        Ast lhs, rhs;
    }
    static struct Lookup {
        Ast lhs;
        string rhs;
    }
    static struct Bin {
        Ast lhs, rhs;
    }

    union PossibleValues {
        string str;
        wstring wstr;
        dstring dstr;
        bool bool_val = void;
        dchar dchar_val = void;
        ulong ulong_val = void;
        real real_val = void;

        Ast next = void;
        Ast[] array = void;
        Ast[] sequence = void;
        Ast[Ast] assocarray = void;
        While while_;
        If if_;
        Bin bin;
        Binop binop;
        Lookup lookup;

        Operator operator;
        struct {
            Operator[] operators;
            Ast[] operands;
        }
    }

    Type type;
    int line = -1;
    string file = "no file";
    PossibleValues values;
    alias values this;

    this(Token t) {
        line = t.line;
        file = t.file;
        if (t.tok == Tok.num) {
            parse_num(t.str);
        } else if (t.tok == Tok.string_) {
            parse_string(t.str);
        } else if (t.tok == Tok.id) {
            type = Type.id;
            str = t.str;
        } else {
            type = Type.other;
            str = t.str;
        }
    }
    this(Type t, Ast[] w) {
        if (!w.empty) {
            file = w[0].file;
            line = w[0].line;
        }
        type = t;
        if (t == Type.sequence) {
            values.sequence = w;
        } else {
            assert (0);
        }
    }

    this(Type t, Ast n) {
        file = n.file;
        line = n.line;
        type = t;
        if (t == Type.statement) {
            next = n;
        } else if (t == Type.binop) {
            str = n.str;
        } else {
            assert (0);
        }
    }
    this(Type t, Ast n1, Ast n2) {
        file = n1.file;
        line = n1.line;
        type = t;
        if (t == Type.while_) {
            values.while_ = While(n1, n2);
        } else if (t == Type.if_) {
            values.if_ = If(n1, n2, null);
        } else if (t == Type.assignment) {
            values.bin = Bin(n1, n2);
        } else {
            assert (0);
        }
    }

    this(Type t, string s, Ast n1, Ast n2) {
        file = n1.file;
        line = n1.line;
        type = t;
        if (t == Type.binop) {
            values.binop = Binop(s, n1, n2);
        } else {
            assert (0);
        }
    }

    this(Type t, Ast n1, string s) {
        file = n1.file;
        line = n1.line;
        type = t;
        if (t == Type.member_lookup) {
            values.lookup = Lookup(n1, s);
        }
    }


    private void parse_string(string s) {
        if (s.front == 'q') {
            type = Type.string_;
            parse_q_string(s);
        } else if (s.back == 'w') {
            type = Type.wstring_;
            s.popBack();
            parse_nondelim_string!wstring(s);
        } else if (s.back == 'd') {
            type = Type.dstring_;
            s.popBack();
            parse_nondelim_string!dstring(s);
        } else if (s.back == 'c') {
            type = Type.string_;
            s.popBack();
            parse_nondelim_string!string(s);
        } else {
            type = Type.string_;
            parse_nondelim_string!string(s);
        }
    }

    private void assign_string(wstring s) {
        wstr = s;
    }
    private void assign_string(dstring s) {
        dstr = s;
    }
    private void assign_string(string s) {
        str = s;
    }
    private void parse_nondelim_string(String)(string s) {
        bool wysiwyg, hex;
        if (s.front == 'r') {
            s.popFront();
            s.popFront();
            s.popBack();
            wysiwyg = true;
        } else if (s.front == '`') {
            s.popFront();
            s.popBack();
            wysiwyg = true;
        } else if (s.front == 'x') {
            s.popFront();
            s.popFront();
            s.popBack();
            hex = true;
        } else {
            s.popFront();
            s.popBack();
        }
        if (hex) {
            assert (0, "DONT SUPPORT HEX YET");
        } else if (wysiwyg) {
            assign_string(to!String(s));
        } else {
            String result;
            for (; !s.empty; s.popFront()) {
                auto x = s.front;
                if (x == '\\') {
                    s.popFront();
                    switch (s.front) {
                        default: enforce(0, "Unknown escape sequence: \\" ~ s[0..1]);
                        case '\'': result ~= '\''; break;
                        case '"': result ~= '"'; break;
                        case '?': result ~= '\?'; break;
                        case 'a': result ~= '\a'; break;
                        case 'b': result ~= '\b'; break;
                        case 'f': result ~= '\f'; break;
                        case 'n': result ~= '\n'; break;
                        case 'r': result ~= '\r'; break;
                        case 't': result ~= '\t'; break;
                        case 'v': result ~= '\v'; break;
                        case 'x': assert (0);
                        case 0: case 1: case 2: case 3: case 4: case 5:
                        case 6: case 7: assert (0);
                        case 'u': assert (0);
                        case 'U': assert (0);
                    }
                } else {
                    result ~= x;
                }
            }
            assign_string(result);
        }
    }

    private void parse_q_string(string s) {
        assert (0);
    }
    private void parse_num(string s) {
        bool L, u, f, dot;

        bool had_suffix = true;
        while (had_suffix) {
            switch (s.back) {
                default: had_suffix = false; break;
                case 'L': L = true; s.popBack(); break;
                case 'u': u = true; s.popBack(); break;
                case 'U': u = true; s.popBack(); break;
                case 'f': f = true; s.popBack(); break;
                case 'F': f = true; s.popBack(); break;
            }
        }

        dot = s.canFind('.');

        bool floating = dot || f;

        if (floating) {
            assert (!u);
            if (L) {
                assert (!f);
                type = Type.real_;
            } else if (f) {
                type = Type.float_;
            } else {
                type = Type.double_;
            }
            real_val = to!real(s);
        } else {
            if (L) {
                type = u ? Type.ulong_ : Type.long_;
            } else {
                type = u ? Type.uint_ : Type.int_;
            }
            ulong_val = to!ulong(s);
        }
    }

    string toString() {
        switch (type) {
            case Type.other:
                return str;
            default: assert (0);

            case Type.real_: case Type.float_: case Type.double_:
                return to!string(real_val);
            case Type.int_: case Type.uint_:
            case Type.long_: case Type.ulong_:
                return to!string(ulong_val);
            case Type.string_:
                return str;
            case Type.wstring_:
                return to!string(wstr);
            case Type.dstring_:
                return to!string(dstr);
            case Type.sequence:
                return format("%(%s; %);", values.sequence);
            case Type.id:
                return str;
            case Type.statement:
                return next.toString();
            case Type.while_:
                return format("while (%s) { %s }",
                        values.while_.condition, values.while_.body_);
            case Type.assignment:
                return format("(%s = %s)", values.bin.lhs, values.bin.rhs);
        }
    }

    IR toIR(CTEnv env) {
        //IR toIR_env(Ast a) { return a.toIR(env); } silly shit

        IR[] wtf;
        
        switch (type) {
            default: assert (0);
            case Type.if_: return ir.if_(
                              values.if_.if_part.toIR(env),
                              values.if_.then_part.toIR(env),
                              values.if_.else_part.toIR(env));
            case Type.while_: return ir.while_(
                                 values.while_.condition.toIR(env),
                                 values.while_.body_.toIR(env));
            case Type.statement: return next.toIR(env);

            case Type.id: return ir.id(str);
            //case Type.sequence: return ir.seq(values.sequence
            //                            .map!toIR_env().array());
            case Type.sequence: 
                          foreach (a; values.sequence) {
                              wtf ~= a.toIR(env);
                          }
                          return ir.seq(wtf);

            case Type.int_: return ir.constant(env, to!int(ulong_val));
            case Type.uint_: return ir.constant(env, to!uint(ulong_val));
            case Type.long_: return ir.constant(env, to!long(ulong_val));
            case Type.ulong_: return ir.constant(env, ulong_val);

            case Type.float_: return ir.constant(env, to!float(real_val));
            case Type.double_: return ir.constant(env, to!double(real_val));
            case Type.real_: return ir.constant(env, real_val);

            case Type.assignment: return ir.set(
                                          bin.lhs.toIR(env),
                                          bin.rhs.toIR(env));
        }
    }
}

Ast ast(T...)(T t) {
    return new Ast(t);
}

