import std.stdio;






R each(alias fun,R)(R r) {
    foreach (ref e; r) {
        fun(e);
    }
    return r;
}

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
