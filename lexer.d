module lexer;

import std.file;

import std.stdio, std.conv, std.typecons, std.exception;
import std.algorithm, std.range, std.array, std.typetuple, std.regex;

import stuff;

enum Tok {
        UNSET,
        abstract_,        //"abstract",                
        alias_,           //"alias",                   
        align_,           //"align",                   
        asm_,             //"asm",                     
        assert_,          //"assert",                  
        auto_,            //"auto",                    
        body_,            //"body",                    
        bool_,            //"bool",                    
        break_,           //"break",                   
        byte_,            //"byte",                    
        case_,            //"case",                    
        cast_,            //"cast",                    
        catch_,           //"catch",                   
        cdouble_,         //"cdouble",                 
        cent_,            //"cent",                    
        cfloat_,          //"cfloat",                  
        char_,            //"char",                    
        class_,           //"class",                   
        const_,           //"const",                   
        continue_,        //"continue",                
        creal_,           //"creal",                   
        dchar_,           //"dchar",                   
        debug_,           //"debug",                   
        default_,         //"default",                 
        delegate_,        //"delegate",                
        delete_,          //"delete",                  
        deprecated_,      //"deprecated",              
        do_,              //"do",                      
        double_,          //"double",                  
        else_,            //"else",                    
        enum_,            //"enum",                    
        export_,          //"export",                  
        extern_,          //"extern",                  
        false_,           //"false",                   
        final_,           //"final",                   
        finally_,         //"finally",                 
        float_,           //"float",                   
        for_,             //"for",                     
        foreach_,         //"foreach",                 
        foreach_reverse_, //"foreach_reverse",         
        function_,        //"function",                
        goto_,            //"goto",                    
        idouble_,         //"idouble",                 
        if_,              //"if",                      
        ifloat_,          //"ifloat",                  
        immutable_,       //"immutable",               
        import_,          //"import",                  
        in_,              //"in",                      
        inout_,           //"inout",                   
        int_,             //"int",                     
        interface_,       //"interface",               
        invariant_,       //"invariant",               
        ireal_,           //"ireal",                   
        is_,              //"is",                      
        lazy_,            //"lazy",                    
        long_,            //"long",                    
        macro_,           //"macro",                   
        mixin_,           //"mixin",                   
        module_,          //"module",                  
        new_,             //"new",                     
        nothrow_,         //"nothrow",                 
        null_,            //"null",                    
        out_,             //"out",                     
        override_,        //"override",                
        package_,         //"package",                 
        pragma_,          //"pragma",                  
        private_,         //"private",                 
        protected_,       //"protected",               
        public_,          //"public",                  
        pure_,            //"pure",                    
        real_,            //"real",                    
        ref_,             //"ref",                     
        return_,          //"return",                  
        scope_,           //"scope",                   
        shared_,          //"shared",                  
        short_,           //"short",                   
        static_,          //"static",                  
        struct_,          //"struct",                  
        super_,           //"super",                   
        switch_,          //"switch",                  
        synchronized_,    //"synchronized",            
        template_,        //"template",                
        this_,            //"this",                    
        throw_,           //"throw",                   
        true_,            //"true",                    
        try_,             //"try",                     
        typedef_,         //"typedef",                 
        typeid_,          //"typeid",                  
        typeof_,          //"typeof",                  
        ubyte_,           //"ubyte",                   
        ucent_,           //"ucent",                   
        uint_,            //"uint",                    
        ulong_,           //"ulong",                   
        union_,           //"union",                   
        unittest_,        //"unittest",                
        ushort_,          //"ushort",                  
        version_,         //"version",                 
        void_,            //"void",                    
        volatile_,        //"volatile",                
        wchar_,           //"wchar",                   
        while_,           //"while",                   
        with_,            //"with",                    
        t__FILE__,        //"__FILE__",                
        t__LINE__,        //"__LINE__",                
        t__gshared,       //"__gshared",               
        t__thread,        //"__thread",                
        dot,              //".",                       
        dotdot,           //"..",                      
        dotdotdot,        //"...",                     
        subsub,           //"--",                      
        addadd,           //"++",                      
        bang,             //"!",                       
        lpar,             //"(",                       
        rpar,             //")",                       
        lbra,             //"[",                       
        rbra,             //"]",                       
        lcurl,            //"{",                       
        rcurl,            //"}",                       
        question,         //"?",                       
        comma,            //",",                       
        semi,             //";",                       
        colon,            //":",                       
        dollar,           //"$",                       
        set,              //"=",                       
        at,               //"@",                       
        arrow,            //"=>",                      
        pound,            //"#",                       

        bangis,           //"!is"
        bangin,           //"!in"

        and,              //"&",                       
        sub,              //"-",                       
        add,              //"+",                       
        star,             //"*",                       
        tilde,            //"~",                       

        div,              //"/",                       
        andand,           //"&&",                      
        or,               //"|",                       
        oror,             //"||",                      
        lt,               //"<",                       
        lteq,             //"<=",                      
        ltlt,             //"<<",                      
        ltgt,             //"<>",                      
        ltgteq,           //"<>=",                     
        gt,               //">",                       
        gteq,             //">=",                      
        gtgt,             //">>",                      
        gtgtgt,           //">>>",                     
        bangeq,           //"!=",                      
        bangltgt,         //"!<>",                     
        bangltgteq,       //"!<>=",                    
        banglt,           //"!<",                      
        banglteq,         //"!<=",                     
        banggt,           //"!>",                      
        banggteq,         //"!>=",                     
        eq,            //"==",                      
        perc,             //"%",                       
        xor,              //"^",                       
        pow,              //"^^",                      
        //bin_op, // all of the above

        div_set,          //"/=",                      
        and_set,          //"&=",                      
        or_set,           //"|=",                      
        sub_set,          //"-=",                      
        add_set,          //"+=",                      
        ltlt_set,         //"<<=",                     
        gtgt_set,         //">>=",                     
        gtgtgt_set,       //">>>=",                    
        star_set,         //"*=",                      
        perc_set,         //"%=",                      
        xor_set,          //"^=",                      
        pow_set,          //"^^=",                     
        tilde_set,        //"~=",                      
        //op_set, // all of the above

        string_,
        char_lit,
        num,
        id,
        eof,
}

struct Loc {
    int line;
    string file;
    string toString() { return text(file,"(",line,")"); }
}
struct Token {
    Loc loc;

    Tok tok;
    string str;

    bool opEquals(Token o) {
        return tok == o.tok
            && loc.line == o.loc.line && loc.file == o.loc.file
            && str == o.str;
    }
}

alias TypeTuple!("\u0020", "\u0009", "\u000B", "\u000C") whitespace;
alias TypeTuple!("\u000D", "\u000A") single_newline;
alias TypeTuple!("\u000D\u000A") double_newline;

alias TypeTuple!(
        "abstract",                Tok.abstract_,
        "alias",                   Tok.alias_,
        "align",                   Tok.align_,
        "asm",                     Tok.asm_,
        "assert",                  Tok.assert_,
        "auto",                    Tok.auto_,
        "body",                    Tok.body_,
        "bool",                    Tok.bool_,
        "break",                   Tok.break_,
        "byte",                    Tok.byte_,
        "case",                    Tok.case_,
        "cast",                    Tok.cast_,
        "catch",                   Tok.catch_,
        "cdouble",                 Tok.cdouble_,
        "cent",                    Tok.cent_,
        "cfloat",                  Tok.cfloat_,
        "char",                    Tok.char_,
        "class",                   Tok.class_,
        "const",                   Tok.const_,
        "continue",                Tok.continue_,
        "creal",                   Tok.creal_,
        "dchar",                   Tok.dchar_,
        "debug",                   Tok.debug_,
        "default",                 Tok.default_,
        "delegate",                Tok.delegate_,
        "delete",                  Tok.delete_,
        "deprecated",              Tok.deprecated_,
        "do",                      Tok.do_,
        "double",                  Tok.double_,
        "else",                    Tok.else_,
        "enum",                    Tok.enum_,
        "export",                  Tok.export_,
        "extern",                  Tok.extern_,
        "false",                   Tok.false_,
        "final",                   Tok.final_,
        "finally",                 Tok.finally_,
        "float",                   Tok.float_,
        "for",                     Tok.for_,
        "foreach",                 Tok.foreach_,
        "foreach_reverse",         Tok.foreach_reverse_, 
        "function",                Tok.function_,
        "goto",                    Tok.goto_,
        "idouble",                 Tok.idouble_,
        "if",                      Tok.if_,
        "ifloat",                  Tok.ifloat_,
        "immutable",               Tok.immutable_,
        "import",                  Tok.import_,
        "in",                      Tok.in_,
        "inout",                   Tok.inout_,
        "int",                     Tok.int_,
        "interface",               Tok.interface_,
        "invariant",               Tok.invariant_,
        "ireal",                   Tok.ireal_,
        "is",                      Tok.is_,
        "lazy",                    Tok.lazy_,
        "long",                    Tok.long_,
        "macro",                   Tok.macro_,
        "mixin",                   Tok.mixin_,
        "module",                  Tok.module_,
        "new",                     Tok.new_,
        "nothrow",                 Tok.nothrow_,
        "null",                    Tok.null_,
        "out",                     Tok.out_,
        "override",                Tok.override_,
        "package",                 Tok.package_,
        "pragma",                  Tok.pragma_,
        "private",                 Tok.private_,
        "protected",               Tok.protected_,
        "public",                  Tok.public_,
        "pure",                    Tok.pure_,
        "real",                    Tok.real_,
        "ref",                     Tok.ref_,
        "return",                  Tok.return_,
        "scope",                   Tok.scope_,
        "shared",                  Tok.shared_,
        "short",                   Tok.short_,
        "static",                  Tok.static_,
        "struct",                  Tok.struct_,
        "super",                   Tok.super_,
        "switch",                  Tok.switch_,
        "synchronized",            Tok.synchronized_,
        "template",                Tok.template_,
        "this",                    Tok.this_,
        "throw",                   Tok.throw_,
        "true",                    Tok.true_,
        "try",                     Tok.try_,
        "typedef",                 Tok.typedef_,
        "typeid",                  Tok.typeid_,
        "typeof",                  Tok.typeof_,
        "ubyte",                   Tok.ubyte_,
        "ucent",                   Tok.ucent_,
        "uint",                    Tok.uint_,
        "ulong",                   Tok.ulong_,
        "union",                   Tok.union_,
        "unittest",                Tok.unittest_,
        "ushort",                  Tok.ushort_,
        "version",                 Tok.version_,
        "void",                    Tok.void_,
        "volatile",                Tok.volatile_,
        "wchar",                   Tok.wchar_,
        "while",                   Tok.while_,
        "with",                    Tok.with_,
        "__FILE__",                Tok.t__FILE__,
        "__LINE__",                Tok.t__LINE__,
        "__gshared",               Tok.t__gshared,
        "__thread",                Tok.t__thread,
        ) keywords;

alias TypeTuple!(
        ".",                       Tok.dot,
        "..",                      Tok.dotdot,
        "...",                     Tok.dotdotdot,
        "&",                       Tok.and,
        "-",                       Tok.sub,
        "--",                      Tok.subsub,
        "+",                       Tok.add,
        "++",                      Tok.addadd,
        "!",                       Tok.bang,
        "(",                       Tok.lpar,
        ")",                       Tok.rpar,
        "[",                       Tok.lbra,
        "]",                       Tok.rbra,
        "{",                       Tok.lcurl,
        "}",                       Tok.rcurl,
        "?",                       Tok.question,
        ",",                       Tok.comma,
        ";",                       Tok.semi,
        ":",                       Tok.colon,
        "$",                       Tok.dollar,
        "=",                       Tok.set,
        "*",                       Tok.star,
        "~",                       Tok.tilde,
        "@",                       Tok.at,
        "=>",                      Tok.arrow,
        "#",                       Tok.pound,

        "!is",                     Tok.bangis,
        "!in",                     Tok.bangin,
        
        "/",                       Tok.div,      
        "&&",                      Tok.andand,   
        "|",                       Tok.or,       
        "||",                      Tok.oror,     

        "<",                       Tok.lt,       
        "<=",                      Tok.lteq,     
        ">",                       Tok.gt,       
        ">=",                      Tok.gteq,     
        "!<>=",                    Tok.bangltgteq,
        "!<>",                     Tok.bangltgt, 
        "<>",                      Tok.ltgt,     
        "<>=",                     Tok.ltgteq,   
        "!>",                      Tok.banggt,   
        "!>=",                     Tok.banggteq, 
        "!<",                      Tok.banglt,   
        "!<=",                     Tok.banglteq, 

        ">>",                      Tok.gtgt,     
        ">>>",                     Tok.gtgtgt,   

        "!=",                      Tok.bangeq,   
        "==",                      Tok.eq,    

        "%",                       Tok.perc,     
        "^",                       Tok.xor,      
        "^^",                      Tok.pow,      
        "<<",                      Tok.ltlt,     

        "/=",                      Tok.div_set,  
        "&=",                      Tok.and_set,  
        "|=",                      Tok.or_set,   
        "-=",                      Tok.sub_set,  
        "+=",                      Tok.add_set,  
        "<<=",                     Tok.ltlt_set, 
        ">>=",                     Tok.gtgt_set, 
        ">>>=",                    Tok.gtgtgt_set,
        "*=",                      Tok.star_set, 
        "%=",                      Tok.perc_set, 
        "^=",                      Tok.xor_set,  
        "^^=",                     Tok.pow_set,  
        "~=",                      Tok.tilde_set,

        ) operators;

template strings(Rest...) {
    static if (Rest.length == 0) {
        alias TypeTuple!() strings;
    } else {
        alias TypeTuple!(Rest[0], strings!(Rest[2 .. $])) strings;
    }
}

template RegexEscapeChar(string s) {
    static if (s == "." || s == "$" || s == "(" || s == ")" || s == "|"
            || s == "+" || s == "*" || s == "?" || s == "{" || s == "}"
            || s == "^" || s == "[" || s == "]" || s == "\\") {
        enum RegexEscapeChar = "\\" ~ s;
    } else {
        enum RegexEscapeChar = s;
    }
}
template RegexEscape(string s) {
    static if (s.length == 0) {
        enum RegexEscape = "";
    } else {
        enum RegexEscape = RegexEscapeChar!(s[0..1]) ~ RegexEscape!(s[1..$]);
    }
}

enum identifyerre = r"[\p{Alphabetic}\p{Mark}\p{Connector_Punctuation}]\w*";

string operatorre; // CTFE bug (can't sort at compile time with -inline,
                   //             or something like that )

enum stringre = `"([^"\\]|\\.)*"`;

enum decexp_q = `([eE][+-]?[_\d]+)?`;
enum hexexp_q = `([pP][+-]?[_\d]+)?`;

enum fsuf_q = `[fFL]*`;

enum numberre = `\.\d[\d_]*` ~ decexp_q ~ fsuf_q
        ~ `|` ~ `\d[\d_]*\.\.` // hack
        ~ `|` ~ `0[xX][0-9a-fA-F_]+(\.[0-9a-fA-F_]*)?` ~ hexexp_q ~ fsuf_q
        ~ `|` ~ `\d[\d_]*(\.\d[\d_]*)?` ~ decexp_q ~ fsuf_q
        ~ `|` ~ `\d[\d_]*` ~ fsuf_q
        ;

enum charre = r"'([^'\\]|\\.[^']*)'";

string finalre; // CTFE bug again

typeof(regex("")) token_re, number_re, ident_re, char_re;
Tok[string] lookup_table;

static this() {
    operatorre = [staticMap!(RegexEscape, strings!operators)
        ].sort!"a.length > b.length"().join("|");
    finalre = "^(" ~ identifyerre
              ~ "|" ~ numberre
              ~ "|" ~ charre
              ~ "|" ~ operatorre
              ~ ")";


    token_re = regex(finalre);
    ident_re = regex("^("~identifyerre~")");
    number_re = regex("^("~numberre~")");
    char_re = regex("^("~charre~")");

    foreach (t; [tuples!(2, operators), tuples!(2, keywords)]) {
        lookup_table[t[0]] = t[1];
    }
}

struct Lexer {
    Token _front;
    string input;
    int line;
    string file;

    this() @disable;

    this(string s, string filename="") {
        file = filename;
        feed(s);
    }

    void feed(string s) {
        if (input.empty) {
            input = s;
            line = 1;
            popFront();
        } else {
            assert (0);
        }
    }

    private bool skipWhitespace() {
        if (input.startsWith(whitespace)) {
            input.popFront();
            return true;
        }
        if (input.startsWith(double_newline)) {
            input.popFront();
            input.popFront();
            line += 1;
            return true;
        }
        if (input.startsWith(single_newline)) {
            input.popFront();
            line += 1;
            return true;
        }
        return false;
    }
    private bool skipComments() {
        if (input.startsWith("//")) {
            auto i2 = input.find("\n");
            if (i2.empty) {
                input = i2;
                return true;
            }
            i2.popFront();

            line += 1;
            input = i2;
            return true;
        } else if (input.startsWith(`/+`, `/*`)) {
            assert (0, "multi line comments unsupported :(");
        }
        return false;
    }

    private void skipNonTokens() {
        while (true) {
            if (!(skipWhitespace() || skipComments())) {
                break;
            }
        }
    }

    // this function is horrible
    private void make_string_token() {

        int starting_line = line;
        auto i2 = input;

        void finalize_token() {
            _front = Token(Loc(starting_line, file), Tok.string_,
                    input[0 .. $ - i2.length]);
            input = i2;
        }

        void parmatch(dchar lpar, dchar rpar, dchar end, int nest=1) {
            for (; !i2.empty; i2.popFront()) {
                auto c = i2.front;
                if (c == end && nest == 0) {
                    i2.popFront();
                    finalize_token();
                    return;
                } else if (c == rpar) {
                    nest -= 1;
                    enforce(nest >= 0);
                } else if (lpar != rpar && c == lpar) {
                    nest += 1;
                } else if (i2.startsWith(double_newline)) {
                    i2.popFront();
                    line += 1;
                } else if (i2.startsWith(single_newline)) {
                    line += 1;
                }
            }
        }

        if (i2.startsWith(`q{`)) {
            i2.popFront();
            i2.popFront();
            return parmatch('{', '}', '}', 0);
        } else if (i2.startsWith(`q"`)) {
            i2.popFront();
            i2.popFront();
            dchar lpar = i2.front, rpar;
            i2.popFront();
            switch (lpar) {
                default: rpar = lpar; break;
                case '[': rpar = ']'; break;
                case '(': rpar = ')'; break;
                case '<': rpar = '>'; break;
                case '{': rpar = '}'; break;

                foreach (s; single_newline) {
                    case s.front: assert (0, "Needs a delimiter!");
                }
                foreach (s; whitespace) {
                    case s.front: assert (0, "Needs a delimiter!");
                }
            }
            return parmatch(lpar, rpar, '"');
        } else if (i2.startsWith(`x"`, `"`, "`")) {
            auto xmode = i2.startsWith(`x`);
            auto rmode = i2.startsWith("`");
            if (xmode) {
                i2.popFront();
            }
            i2.popFront();
            for (; !i2.empty; i2.popFront()) {
                auto c = i2.front;
                if (i2.startsWith(double_newline)) {
                    i2.popFront();
                    line += 1;
                } else if (i2.startsWith(single_newline)) {
                    line += 1;
                } else if (!xmode && !rmode && i2.startsWith(`\`)) {
                    i2.popFront();
                } else if ((!rmode && c == '"') || (rmode && c == '`')) {
                    i2.popFront();
                    finalize_token();
                    return;
                }
            }
            finalize_token();
            return;
        } else if (i2.startsWith(`"`)) {
            i2.popFront();
            for (; !i2.empty; i2.popFront()) {
                auto c = i2.front;
            }
            finalize_token();
            return;
        } else {
            assert (0);
        }

        assert (0);
    }

    Token front() @property {
        return _front;
    }
    void popFront() {
        skipNonTokens();

        if (input.empty) {
            _front = Token(Loc(line, file), Tok.eof, "");
            return;
        }

        if (input.startsWith(`q"`, `q{`, `x"`, `"`, "`")) {
            make_string_token();
            return;
        }

        auto cap = match(input, token_re).captures[0];
        if (!cap.startsWith(".") && cap.endsWith("..")) {
            cap = cap[0 .. $-2]; // HACK
        }

        if (cap.length == 0) {
            writeln("error(",line,"): ", tuple(input[0 .. min($, 30)]));
            input = "";
            popFront();
            return;
        }
        input = input[cap.length .. $];

        Tok tok;

        auto f = cap in lookup_table;
        if (f !is null) {
            tok = *f;
        } else if (cap.match(char_re)) {
            tok = Tok.char_lit;
        } else if (cap.match(number_re)) {
            tok = Tok.num;
        } else if (cap.match(ident_re)) {
            tok = Tok.id;
        } else {
            assert (0);
        }
        _front = Token(Loc(line, file), tok, cap);
    }
    bool empty() @property {
        return _front.tok == Tok.eof && input.empty;
    }
}

unittest {
    string input;
    
    input = "_1";
    assert (equal(Lexer(input), [
                Token(1, "", Tok.id, "_1"),
                ]),
            text(Lexer(input)));
    input = "_a";
    assert (equal(Lexer(input), [
                Token(1, "", Tok.id, "_a"),
                ]),
            text(Lexer(input)));


    input = "q{{asdf}} \nq\"/asdf/\" \n x\"1234\" \n \"as\\\"d\nf\" a _1";
    assert (equal(Lexer(input), [
                Token(1, "", Tok.string_, "q{{asdf}}"),
                Token(2, "", Tok.string_, "q\"/asdf/\""),
                Token(3, "", Tok.string_, "x\"1234\""),
                Token(4, "", Tok.string_, "\"as\\\"d\nf\""),
                Token(5, "", Tok.id, "a"),
                Token(5, "", Tok.id, "_1"),
                ]),
            text(Lexer(input)));


    input = "123_456.567_8         // 123456.5678
        1_2_3_4_5_6_.5_6_7_8 // 123456.5678
        1_2_3_4_5_6_.5e-6_   // 123456.5e-6";

    assert (equal(Lexer(input), [
                Token(1, "", Tok.num, "123_456.567_8"),
                Token(2, "", Tok.num, "1_2_3_4_5_6_.5_6_7_8"),
                Token(3, "", Tok.num, "1_2_3_4_5_6_.5e-6_"),
                ]),
            text(Lexer(input)));


    input = "
        0x1.FFFFFFFFFFFFFp1023 // double.max
        0x1p-52                // double.epsilon
        1.175494351e-38F       // float.min
        ";

    assert (equal(Lexer(input), [
                Token(2, "", Tok.num, "0x1.FFFFFFFFFFFFFp1023"),
                Token(3, "", Tok.num, "0x1p-52"),
                Token(4, "", Tok.num, "1.175494351e-38F"),
                ]),
            text(Lexer(input)));
    assert (to!real("123456.78e90") == 12_34_56.78e90L);
    assert (to!double("0x1.FFFFFFFFFFFFFp1023") == 0x1.FFFFFFFFFFFFFp1023);
}

