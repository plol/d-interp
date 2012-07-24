module internal.ast;

import std.array, std.string, std.algorithm, std.range, std.conv;
import std.exception, std.stdio, std.typecons;

import internal.typeinfo;

import internal.ir;
alias internal.ir ir;

import internal.ctenv;
import lexer;
import stuff;

alias stuff.format format;


struct TypeMod {
    static enum Type {
        none,

        pointer,
        array,
        slicy, // [int], [10]

        const_,
        immutable_,
        inout_,
        shared_,
    }
    Type type;
    Ast ast;
}
static struct TypeData {
    TypeMod mod;
    Ast ast;
}

final class Ast {
    static enum Type {
        nothing,

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

        condexpr,

        cast_,

        type,
        type_mod,
        basic_type,

        assignment,
        op_assignment,

        typeid_,
        typeof_,

        addressof,
        deref,

        member_lookup,
        module_lookup,

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
        bool bool_val;
        dchar dchar_val;
        ulong ulong_val;
        real real_val;

        Ast next;
        Ast[] array;
        Ast[] sequence;
        Ast[Ast] assocarray;
        While while_;
        If if_;
        Bin bin;
        Binop binop;
        Lookup lookup;
        TI.Type ti_type;
        TypeData typedata;
        TypeMod type_mod;
    }

    Type type;
    Loc loc;
    PossibleValues values;
    alias values this;

    this(Token t) {
        loc = t.loc;
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
    this(Type t, Loc l, TI.Type ti) {
        type = t;
        loc = l;
        if (t == Type.basic_type) {
            ti_type = ti;
        } else {
            assert (0);
        }
    }

    this(Type t, TypeMod.Type tm) {
        this(t, Loc(0, "unspecified"), tm);
    }
    this(Type t, Loc l, TypeMod.Type tm) {
        type = t;
        loc = l;
        if (t == Type.type_mod) {
            type_mod = TypeMod(tm);
        } else {
            assert (0);
        }
    }
    this(Type t, TypeMod.Type tm, Ast n1) {
        this(t, Loc(0, "unspecified"), tm, n1);
    }
    this(Type t, Loc l, TypeMod.Type tm, Ast n1) {
        type = t;
        loc = l;
        if (t == Type.type_mod) {
            type_mod = TypeMod(tm, n1);
        } else {
            assert (0, text(t));
        }
    }

    this(Type t, Loc l, TypeMod tm, Ast n1) {
        type = t;
        loc = l;
        if (t == Type.type) {
            typedata = TypeData(tm, n1);
        } else {
            assert (0);
        }
    }


    this(Type t, Loc l) {
        loc = l;
        if (t == Type.nothing) {
        } else {
            assert (0);
        }
    }
    this(Type t, Ast[] w) {
        this(t, Loc(0, "unspecified"), w);
    }
    this(Type t, Loc l, Ast[] w) {
        loc = l;
        type = t;
        if (t == Type.sequence) {
            values.sequence = w;
        } else {
            assert (0);
        }
    }

    this(Type t, Ast n) { this(t, n.loc, n); }
    this(Type t, Loc l, Ast n) {
        loc = l;
        type = t;
        if (t == Type.statement) {
            next = n;
        } else if (t == Type.binop) {
            str = n.str;
        } else if (t == Type.module_lookup) {
            next = n;
        } else if (t == Type.type) {
            typedata = TypeData(TypeMod(TypeMod.Type.none), n);
        } else {
            assert (0);
        }
    }
    this(Type t, Loc l, Ast n1, Ast n2) {
        loc = l;
        type = t;
        if (t == Type.while_) {
            values.while_ = While(n1, n2);
        } else if (t == Type.if_) {
            assert (0); values.if_ = If(n1, n2, null);
        } else if (t == Type.assignment) {
            values.bin = Bin(n1, n2);
        } else if (t == Type.application) {
            values.bin = Bin(n1, n2);
        } else {
            assert (0);
        }
    }
    this(Type t, Loc l, Ast n1, Ast n2, Ast n3) {
        loc = l;
        type = t;
        if (t == Type.if_) {
            values.if_ = If(n1, n2, n3);
        } else {
            assert (0);
        }
    }

    this(Type t, Loc l, string s, Ast n1, Ast n2) {
        loc = l;
        type = t;
        if (t == Type.binop) {
            values.binop = Binop(s, n1, n2);
        } else {
            assert (0);
        }
    }

    this(Type t, Loc l, Ast n1, string s) {
        loc = l;
        type = t;
        if (t == Type.member_lookup) {
            values.lookup = Lookup(n1, s);
        } else {
            assert (0);
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
            default: assert (0, text(type));

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
            case Type.binop:
                return format("(%s %s %s)",
                        values.binop.lhs, values.binop.op, values.binop.rhs);
            case Type.basic_type:
                return format("%s", ti_type);
            case Type.type:
                return format_type(values.typedata);
        }
    }
}

string format_type(TypeData td) {
    switch (td.mod.type) {
        default: assert (0);
        case TypeMod.Type.none: return format("%s", td.ast);
        case TypeMod.Type.pointer: return format("%s*", td.ast);
        case TypeMod.Type.array: return format("%s[]", td.ast);
        case TypeMod.Type.slicy: return format("%s[%s]", td.ast, td.mod.ast);
        case TypeMod.Type.const_: return format("const(%s)", td.ast);
        case TypeMod.Type.immutable_: return format("immutable(%s)", td.ast);
        case TypeMod.Type.inout_: return format("inout(%s)", td.ast);
        case TypeMod.Type.shared_: return format("shared(%s)", td.ast);
    }
}

Ast ast(T...)(T t) {
    return new Ast(t);
}

