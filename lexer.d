module lexer;

import std.stdio, std.conv;
import std.algorithm, std.range, std.array;

import stuff;

struct Token {
    int line;
    string str;
}

enum whitespace = ["\u0020", "\u0009", "\u000B", "\u000C"];
enum newline = ["\u000D", "\u000A", "\u000D\u000A"];
enum keywords = ["abstract", "alias", "align", "asm", "assert", "auto", "body",
              "bool", "break", "byte", "case", "cast", "catch", "cdouble",
              "cent", "cfloat", "char", "class", "const", "continue", "creal",
              "dchar", "debug", "default", "delegate", "delete", "deprecated",
              "do", "double", "else", "enum", "export", "extern", "false",
              "final", "finally", "float", "for", "foreach", "foreach_reverse",
              "function", "goto", "idouble", "if", "ifloat", "immutable",
              "import", "in", "inout", "int", "interface", "invariant",
              "ireal", "is", "lazy", "long", "macro", "mixin", "module", "new",
              "nothrow", "null", "out", "override", "package", "pragma",
              "private", "protected", "public", "pure", "real", "ref",
              "return", "scope", "shared", "short", "static", "struct",
              "super", "switch", "synchronized", "template", "this", "throw",
              "true", "try", "typedef", "typeid", "typeof", "ubyte", "ucent",
              "uint", "ulong", "union", "unittest", "ushort", "version",
              "void", "volatile", "wchar", "while", "with", "__FILE__",
              "__LINE__", "__gshared", "__thread", "__traits"];

/* semi-retarded challenges:
 *
 * [1..2] needs to be '[' '1' '..' '2' ']'
 *                not '[' '1.' '.2' ']'
 *
 * Delimited and raw strings are weird.
 * 
 * I wanna make a lexer that can be like
 * 
 * start = end = "\ escape = "\\"
 *
 * start = "\"(", end = ")\ escape = ""
 *
 * start = end = "`", escape = ""
 *
 */

struct Trie(K,V) {
    alias ElementType!K E;
    private Trie[E] nexts;
    private V* _word;

    ref V value() @property {
        return *_word;
    }

    this(K[] ks, V[] vs) {

        zip(ks, vs).sort();

        auto completes = vs[0 .. ks.until!"a.length > 0"().walkLength];
        assert (completes.length <= 1, text(completes));
        if (completes.length == 1) {
            _word = &completes[0];
        }

        ks = ks[completes.length .. $];
        vs = vs[completes.length .. $];

        while (!ks.empty) {
            auto f = ks[0].front;

            bool starts_with_diff(K a) { // bug
                return a.front != f;
            }

            size_t len = ks.until!starts_with_diff() .walkLength();

            foreach (i; 0 .. len) {
                ks[i].popFront();
            }

            nexts[f] = Trie(ks[0 .. len], vs[0 .. len]);
            ks = ks[len .. $];
            vs = vs[len .. $];
        }
    }

    bool complete() const @property {
        return _word !is null;
    }

    bool opIn_r(E d) {
        return (d in nexts) != null;
    }
    Trie opIndex(E d) {
        return nexts[d];
    }
    Trie opIndex(K s) {
        if (s.empty) return this;
        auto f = s.front;
        s.popFront;
        return this[f][s];
    }

    string toString() {
        return "Trie: " ~ toString2();
    }

    private string toString2() {
        bool needs_paren = (complete && nexts.length > 0) || nexts.length > 1;
        string s;
        
        if (needs_paren) {
            s = "(";
        }

        if (complete) {
            s ~= ":";
            s ~= to!string(value);
            if (nexts.length != 0) {
                s ~= " ";
            }
        }


        // Cannot inline this function as
        // something cannot get frame pointer to map
        string f(typeof(zip(nexts.keys, nexts.values).front) a) {
            return text(a[0], a[1].toString2()); // BUG BUG BUG
        }

        s ~= zip(nexts.keys, nexts.values)
            //.map!(a => text(a[0], a[1].toString2())) // BUG BUG BUG
            .map!f() // BUG BUG BUG
            .join(", ");

        if (needs_paren) {
            s ~= ")";
        }
        return s;
    }

    void mergeWith(Trie b) {
        foreach (c, t; b.nexts) {
            if (c in nexts) {
                nexts[c].mergeWith(t);
            } else {
                nexts[c] = t;
            }
        }
    }
}

struct W {
    alias Trie!(string, string) T;
    T start, cur;

    this(T t) {
        start = cur = t;
    }

    void reset() {
        cur = start;
    }
    bool feed(dchar d) {
        if (d in cur) {
            cur = cur[d];
            return true;
        }
        return false;
    }
    bool complete() @property {
        return cur.complete;
    }
    string value() @property {
        return cur.value;
    }
}

void main() {
    auto kws = Trie!(string, string)(keywords.dup, keywords);

    string w = "alias this";

    auto t2 = kws;

    W l = W(kws);
    while (l.feed(w.front)) {
        w.popFront();
    }
    assert(l.complete);
    writeln(l.value);

    //writeln(kws);
    //writeln(t2);


    [1,2,3].each!((ref a) => a += 1 )().each!(a => writeln(a))().writeln();
}
