module lexer;

import std.stdio, std.conv;
import std.algorithm, std.range, std.array;

struct Token {
    int line;
    string str;
    TOK tok;
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

struct Trie {
    Trie[dchar] nexts;
    string word;

    this(string[] strings) {
        this(strings, strings.array());
    }

    private this(string[] begins, string[] finals) {
        sort(zip(begins, finals));

        auto completes = finals[0 .. begins.until!"a.length > 0"().walkLength];
        assert (completes.length <= 1, text(completes));
        if (completes.length == 1) {
            word = completes[0];
        }

        begins = begins[completes.length .. $];
        finals = finals[completes.length .. $];

        while (!begins.empty) {
            dchar f = begins[0].front;
            bool starts_with_different_than_first(string a) {
                return a.front != f;
            }

            auto sames = begins.until!starts_with_different_than_first();

            size_t len = sames.walkLength;

            foreach (i; 0 .. len) {
                begins[i].popFront();
            }

            nexts[f] = Trie(begins[0 .. len], finals[0 .. len]);
            begins = begins[len .. $];
            finals = finals[len .. $];
        }
    }

    bool complete() const @property {
        return word.length > 0;
    }

    bool opIn_r(dchar d) {
        return (d in nexts) != null;
    }
    Trie opIndex(dchar d) {
        return nexts[d];
    }
    Trie opIndex(string s) {
        if (s.empty) return this;
        auto f = s.front;
        s.popFront;
        return this[f][s];
    }

    string toString() {
        return "Trie: " ~ toString2("\n");
    }

    private string toString2(string joiner = ", ") {
        bool needs_paren = (complete && nexts.length > 0) || nexts.length > 1;
        string s;
        
        if (needs_paren) {
            s = "(";
        }

        if (complete) {
            s ~= ":\"";
            s ~= word;
            s ~= '"';
            if (nexts.length != 0) {
                s ~= " ";
            }
        }

        s ~= zip(nexts.keys, nexts.values)
            .map!(a => text(a[0], "", a[1].toString2()))
            .join(joiner);

        if (needs_paren) {
            s ~= ")";
        }
        return s;
    }
}


void main() {
    auto t = Trie(keywords);

    string w = "alias this";

    auto t2 = t;

    foreach (dchar c; w) {
        if (c in t) {
            t2 = t2[c];
        } else {
            writeln(t2.complete);
            if (t2.complete) {
                writeln("found word ", t2.word);
            }
            break;
        }
    }

    writeln(t);
    writeln(t2);
}
