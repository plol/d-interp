module lexer;

import std.stdio, std.conv, std.typecons, std.exception;
import std.algorithm, std.range, std.array, std.typetuple, std.regex;

import stuff;

enum TOK {
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
        div,              //"/",                       
        div_ass,          //"/=",                      
        dot,              //".",                       
        dotdot,           //"..",                      
        dotdotdot,        //"...",                     
        bitand,           //"&",                       
        bitand_ass,       //"&=",                      
        andand,           //"&&",                      
        bitor,            //"|",                       
        bitor_ass,        //"|=",                      
        oror,             //"||",                      
        sub,              //"-",                       
        sub_ass,          //"-=",                      
        subsub,           //"--",                      
        add,              //"+",                       
        add_ass,          //"+=",                      
        addadd,           //"++",                      
        lt,               //"<",                       
        lteq,             //"<=",                      
        ltlt,             //"<<",                      
        ltlt_ass,         //"<<=",                     
        ltgt,             //"<>",                      
        ltgteq,           //"<>=",                     
        gt,               //">",                       
        gteq,             //">=",                      
        gtgt_ass,         //">>=",                     
        gtgtgt_ass,       //">>>=",                    
        gtgt,             //">>",                      
        gtgtgt,           //">>>",                     
        bang,             //"!",                       
        bangeq,           //"!=",                      
        bangltgt,         //"!<>",                     
        bangltgteq,       //"!<>=",                    
        banglt,           //"!<",                      
        banglteq,         //"!<=",                     
        banggt,           //"!>",                      
        banggteq,         //"!>=",                     
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
        ass,              //"=",                       
        equal,            //"==",                      
        star,             //"*",                       
        star_ass,         //"*=",                      
        perc,             //"%",                       
        perc_ass,         //"%=",                      
        bitxor,           //"^",                       
        pow,              //"^^",                      
        bitxor_ass,       //"^=",                      
        pow_ass,          //"^^=",                     
        tilde,            //"~",                       
        tilde_ass,        //"~=",                      
        at,               //"@",                       
        arrow,            //"=>",                      
        pound,            //"#",                       

        string_,
        num,
        id,
        eof,
}

struct Token {
    int line;
    string str;
    TOK tok;
    alias tok this;
}

alias TypeTuple!("\u0020", "\u0009", "\u000B", "\u000C") whitespace;
alias TypeTuple!("\u000D", "\u000A") single_newline;
alias TypeTuple!("\u000D\u000A") double_newline;

alias TypeTuple!(
        "abstract",                TOK.abstract_,
        "alias",                   TOK.alias_,
        "align",                   TOK.align_,
        "asm",                     TOK.asm_,
        "assert",                  TOK.assert_,
        "auto",                    TOK.auto_,
        "body",                    TOK.body_,
        "bool",                    TOK.bool_,
        "break",                   TOK.break_,
        "byte",                    TOK.byte_,
        "case",                    TOK.case_,
        "cast",                    TOK.cast_,
        "catch",                   TOK.catch_,
        "cdouble",                 TOK.cdouble_,
        "cent",                    TOK.cent_,
        "cfloat",                  TOK.cfloat_,
        "char",                    TOK.char_,
        "class",                   TOK.class_,
        "const",                   TOK.const_,
        "continue",                TOK.continue_,
        "creal",                   TOK.creal_,
        "dchar",                   TOK.dchar_,
        "debug",                   TOK.debug_,
        "default",                 TOK.default_,
        "delegate",                TOK.delegate_,
        "delete",                  TOK.delete_,
        "deprecated",              TOK.deprecated_,
        "do",                      TOK.do_,
        "double",                  TOK.double_,
        "else",                    TOK.else_,
        "enum",                    TOK.enum_,
        "export",                  TOK.export_,
        "extern",                  TOK.extern_,
        "false",                   TOK.false_,
        "final",                   TOK.final_,
        "finally",                 TOK.finally_,
        "float",                   TOK.float_,
        "for",                     TOK.for_,
        "foreach",                 TOK.foreach_,
        "foreach_reverse",         TOK.foreach_reverse_, 
        "function",                TOK.function_,
        "goto",                    TOK.goto_,
        "idouble",                 TOK.idouble_,
        "if",                      TOK.if_,
        "ifloat",                  TOK.ifloat_,
        "immutable",               TOK.immutable_,
        "import",                  TOK.import_,
        "in",                      TOK.in_,
        "inout",                   TOK.inout_,
        "int",                     TOK.int_,
        "interface",               TOK.interface_,
        "invariant",               TOK.invariant_,
        "ireal",                   TOK.ireal_,
        "is",                      TOK.is_,
        "lazy",                    TOK.lazy_,
        "long",                    TOK.long_,
        "macro",                   TOK.macro_,
        "mixin",                   TOK.mixin_,
        "module",                  TOK.module_,
        "new",                     TOK.new_,
        "nothrow",                 TOK.nothrow_,
        "null",                    TOK.null_,
        "out",                     TOK.out_,
        "override",                TOK.override_,
        "package",                 TOK.package_,
        "pragma",                  TOK.pragma_,
        "private",                 TOK.private_,
        "protected",               TOK.protected_,
        "public",                  TOK.public_,
        "pure",                    TOK.pure_,
        "real",                    TOK.real_,
        "ref",                     TOK.ref_,
        "return",                  TOK.return_,
        "scope",                   TOK.scope_,
        "shared",                  TOK.shared_,
        "short",                   TOK.short_,
        "static",                  TOK.static_,
        "struct",                  TOK.struct_,
        "super",                   TOK.super_,
        "switch",                  TOK.switch_,
        "synchronized",            TOK.synchronized_,
        "template",                TOK.template_,
        "this",                    TOK.this_,
        "throw",                   TOK.throw_,
        "true",                    TOK.true_,
        "try",                     TOK.try_,
        "typedef",                 TOK.typedef_,
        "typeid",                  TOK.typeid_,
        "typeof",                  TOK.typeof_,
        "ubyte",                   TOK.ubyte_,
        "ucent",                   TOK.ucent_,
        "uint",                    TOK.uint_,
        "ulong",                   TOK.ulong_,
        "union",                   TOK.union_,
        "unittest",                TOK.unittest_,
        "ushort",                  TOK.ushort_,
        "version",                 TOK.version_,
        "void",                    TOK.void_,
        "volatile",                TOK.volatile_,
        "wchar",                   TOK.wchar_,
        "while",                   TOK.while_,
        "with",                    TOK.with_,
        "__FILE__",                TOK.t__FILE__,
        "__LINE__",                TOK.t__LINE__,
        "__gshared",               TOK.t__gshared,
        "__thread",                TOK.t__thread,
        ) keywords;

alias TypeTuple!(
        "/",                       TOK.div,
        "/=",                      TOK.div_ass,
        ".",                       TOK.dot,
        "..",                      TOK.dotdot,
        "...",                     TOK.dotdotdot,
        "&",                       TOK.bitand,
        "&=",                      TOK.bitand_ass,
        "&&",                      TOK.andand,
        "|",                       TOK.bitor,
        "|=",                      TOK.bitor_ass,
        "||",                      TOK.oror,
        "-",                       TOK.sub,
        "-=",                      TOK.sub_ass,
        "--",                      TOK.subsub,
        "+",                       TOK.add,
        "+=",                      TOK.add_ass,
        "++",                      TOK.addadd,
        "<",                       TOK.lt,
        "<=",                      TOK.lteq,
        "<<",                      TOK.ltlt,
        "<<=",                     TOK.ltlt_ass,
        "<>",                      TOK.ltgt,
        "<>=",                     TOK.ltgteq,
        ">",                       TOK.gt,
        ">=",                      TOK.gteq,
        ">>=",                     TOK.gtgt_ass,
        ">>>=",                    TOK.gtgtgt_ass,
        ">>",                      TOK.gtgt,
        ">>>",                     TOK.gtgtgt,
        "!",                       TOK.bang,
        "!=",                      TOK.bangeq,
        "!<>",                     TOK.bangltgt,
        "!<>=",                    TOK.bangltgteq,
        "!<",                      TOK.banglt,
        "!<=",                     TOK.banglteq,
        "!>",                      TOK.banggt,
        "!>=",                     TOK.banggteq,
        "(",                       TOK.lpar,
        ")",                       TOK.rpar,
        "[",                       TOK.lbra,
        "]",                       TOK.rbra,
        "{",                       TOK.lcurl,
        "}",                       TOK.rcurl,
        "?",                       TOK.question,
        ",",                       TOK.comma,
        ";",                       TOK.semi,
        ":",                       TOK.colon,
        "$",                       TOK.dollar,
        "=",                       TOK.ass,
        "==",                      TOK.equal,
        "*",                       TOK.star,
        "*=",                      TOK.star_ass,
        "%",                       TOK.perc,
        "%=",                      TOK.perc_ass,
        "^",                       TOK.bitxor,
        "^^",                      TOK.pow,
        "^=",                      TOK.bitxor_ass,
        "^^=",                     TOK.pow_ass,
        "~",                       TOK.tilde,
        "~=",                      TOK.tilde_ass,
        "@",                       TOK.at,
        "=>",                      TOK.arrow,
        "#",                       TOK.pound,
        ) operators;

template strings(Rest...) {
    static if (Rest.length == 0) {
        alias TypeTuple!() strings;
    } else {
        alias TypeTuple!(Rest[0], strings!(Rest[2 .. $])) strings;
    }
}
template tuples(Rest...) {
    static if (Rest.length == 0) {
        alias TypeTuple!() tuples;
    } else {
        alias TypeTuple!(tuple(Rest[0], Rest[1]), tuples!(Rest[2 .. $])) tuples;
    }
}

template RegexEscapeChar(string s) {
    static if (s == "." || s == "\\" || s == "(" || s == ")" || s == "|"
            || s == "+" || s == "*" || s == "?" || s == "{" || s == "}"
            || s == "^" || s == "$" || s == "[" || s == "]") {
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

string fuck_it() {
    char[] s = [strings!operators].join("").dup;
    (cast(ubyte[])s).sort();

    string ret;
    foreach (c; s) {
        if (!ret.empty && c == ret.back) continue;
        ret ~= c;
    }

    return ret;
}

enum opchars = RegexEscape!(fuck_it());

//enum identifyerre = "([^" ~ opchars ~ "\\s\\d\"][^" ~ opchars ~ "\\s\"]*)";
//enum identifyerre = r"\w(\w|\d)*";
enum identifyerre = r"[\p{Alphabetic}]\w*";

enum operatorre = [staticMap!(RegexEscape, strings!operators)
    ].sort!"a.length > b.length"().join("|");

enum stringre = `"([^"\\]|\\.)*"`;
enum numberre = `\.\d+|(\d+)\.\.|\d+\.\d*|0x[0-9a-fA-F]+|\d+`;
enum finalre = "^(" ~ identifyerre
              ~ "|" ~ numberre
              ~ "|" ~ operatorre
              ~ ")";


typeof(regex("")) token_re, string_re, number_re, ident_re;
TOK[string] lookup_table;

static this() {
    token_re = regex(finalre);
    ident_re = regex(identifyerre);
    number_re = regex(numberre);

    foreach (t; [tuples!operators, tuples!keywords]) {
        lookup_table[t[0]] = t[1];
    }
}

struct Lexer {
    Token _front;
    string input;
    int line;

    this() @disable;

    this(string s) {
        feed(s);
    }

    void feed(string s) {
        if (input.empty) {
            input = s;
            line = 0;
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
            _front = Token(starting_line,
                    input[0 .. $ - i2.length], TOK.string_);
            input = i2;
        }

        void parmatch(dchar lpar, dchar rpar, dchar end) {
            int nest = 1;
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
            return parmatch('{', '}', '}');
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
        } else if (i2.startsWith(`x"`, `"`)) {
            auto xmode = i2.startsWith(`x`);
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
                } else if (!xmode && i2.startsWith(`\`)) {
                    i2.popFront();
                } else if (c == '"') {
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
            _front = Token(line, "", TOK.eof);
            return;
        }

        if (input.startsWith(`q"`, `q{`, `x"`, `"`)) {
            make_string_token();
            return;
        }

        auto cap = match(input, token_re).captures[0];
        if (!cap.startsWith(".") && cap.endsWith("..")) {
            cap = cap[0 .. $-2]; // HACK
        }

        if (cap.length == 0) {
            writeln("error");
            input = "";
            popFront();
            return;
        }
        input = input[cap.length .. $];

        TOK tok;

        auto f = cap in lookup_table;
        if (f !is null) {
            tok = *f;
        } else if (cap.match(number_re)) {
            tok = TOK.num;
        } else if (cap.match(ident_re)) {
            tok = TOK.id;
        } else {
            assert (0);
        }
        _front = Token(line, cap, tok);
    }
    bool empty() @property {
        return _front.tok == TOK.eof && input.empty;
    }
}

void main() {

    //hackety time


    auto input = "while(a<123){\r\na+=1;\r\n \"foo\"}\r foreach(i ; 0..1) f();";
    input ~= " q\"/as
        df/\"   x\"12 34 4\" \"\\\"\"";

    foreach (token; Lexer(input)) {
        writeln(token);
    }

}
