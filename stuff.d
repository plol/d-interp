import std.stdio;

import std.typecons, std.functional, std.conv, std.traits, std.range;
import std.format, std.array, std.string, std.algorithm;
import std.typetuple;

template tuples(int n, Rest...) {
    static assert (Rest.length % n == 0);
    static if (Rest.length == 0) {
        alias TypeTuple!() tuples;
    } else {
        alias TypeTuple!(tuple(Rest[0 .. n]), tuples!(n, Rest[n .. $])) tuples;
    }
}

string format(T...)(T t) {
    auto app = appender!string();
    formattedWrite(app, t);
    return app.data;
}

T[] make_set(T)(ref T[] ts) {
    auto rest = ts.sort().release().uniq().copy(ts);
    ts = ts[0 .. $ - rest.length];
    return ts;
}

T[] extend(T)(ref T[] ts, T[] os) {
    ts = ts.dup;
    ts ~= os;
    return ts.make_set();
}

R tail(R)(R r) if (isInputRange!R) {
    r.popFront();
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

            size_t len = ks.until!starts_with_diff().walkLength();

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
struct TrieSet(K) {
    alias ElementType!K E;
    private Tuple!(E, TrieSet)[] nexts;
    bool complete;

    private auto nextsFor(E e) {
        auto dummy = tuple(e, TrieSet());
        return assumeSorted!"a[0] < b[0]"(nexts).equalRange(dummy).release();
    }

    this(K k) {
        insert(k);
    }

    void insert(K k) {
        if (k.empty) {
            complete = true;
            return;
        }
        auto f = k.front;
        k.popFront();
        auto nexts1 = nextsFor(f);
        if (nexts1.empty) {
            nexts ~= tuple(f, TrieSet(k));
            insertionSort_1!"a[0] < b[0]"(nexts);
        } else {
            assert (nexts1.length == 1);
            nexts1.front[1].insert(k);
        }
    }

    bool opIn_r(K k) {
        if (k.empty) return complete;
        auto f = k.front;
        k.popFront();
        auto nexts1 = nextsFor(f);
        return !nexts1.empty && k in nexts1.front[1];
    }

    string toString() {
        string ret = complete ? "(." : "(";
        foreach (n; nexts) {
            ret ~= text(n[0], ":", n[1]);
        }
        ret ~= ")";
        return ret;
    }
}

unittest {
    auto t = TrieSet!string("Hello");
    t.insert("Howdy");
    t.insert("Hello there!");

    assert ("Howdy" in t, text(t));
    assert ("Hello" in t);
    assert ("Hello there!" in t);
    assert ("Hello the" !in t);
    assert ("" !in t);
    assert ("foo" !in t);
}


// assumes all range is sorted except last element, which is moved backwards
void insertionSort_1(alias less="a < b", R)(R r) {
    alias binaryFun!less f;

    auto idx = r.length - 1;
    while (idx > 0 && f(r[idx], r[idx-1])) {
        swap(r[idx-1], r[idx]);
        idx -= 1;
    }
}

unittest {
    auto a = [1,2,4,5,6,3];
    a.insertionSort_1();
    assert (a == [1,2,3,4,5,6], text(a));
    auto b = [tuple(1,2),tuple(3,0),tuple(2,1)];
    b.insertionSort_1!"a[0] < b[0]"();
    assert (b == [tuple(1,2),tuple(2,1),tuple(3,0)], text(b));
}


struct StupidMap(alias f, R) {
    R r;
    auto front() @property {
        return f(r.front);
    }
    void popFront() {
        auto f = r.front;
        while (!r.empty && r.front == f) {
            r.popFront();
        }
    }
    bool empty() @property {
        return r.empty;
    }
}
auto stupid_map(alias f, R)(R r) {
    return StupidMap!(f, R)(r);
}

struct StupidUniq(R) {
    R r;
    auto front() @property {
        return r.front;
    }
    void popFront() {
        auto f = r.front;
        while (!r.empty && r.front == f) {
            r.popFront();
        }
    }
    bool empty() @property {
        return r.empty;
    }
}
auto stupid_uniq(R)(R r) {
    return StupidUniq!R(r);
}



string simpleCmp(string o, string[] ms...) {
    string ret;
    foreach (m; ms) {
        ret ~= "if (" ~ m ~ " < " ~ o ~ "." ~ m ~") { return -1; }\n";
        ret ~= "if (" ~ m ~ " > " ~ o ~ "." ~ m ~") { return 1; }\n";
    }
    ret ~= "return 0;";
    return ret;
}
