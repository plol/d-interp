module parsergen;

import std.file, std.format;

import std.stdio, std.conv, std.typecons, std.exception;
import std.algorithm, std.range, std.array, std.typetuple, std.regex;
import std.datetime;

import stuff;

struct Rule(Tok) {
    string name;
    Sym!Tok[] syms;
    alias syms this;

    this(string s, Sym!Tok[] res) {
        name = s;
        syms = res;
    }

    bool opEquals(Rule o) {
        return name == o.name && syms == o.syms;
    }
    int opCmp(Rule o) { mixin (simpleCmp("o", "name", "syms")); }
    string toString() {
        return text(name, " -> ", syms);
    }
}
Rule!Tok rule(Tok, Ts...)(Ts ts) {
    Sym!Tok[] ret;
    foreach (T t; ts[1..$]) {
        ret ~= Sym!Tok(t);
    }
    return Rule!Tok(ts[0], ret);
}

private struct Sym(Tok) {
    bool terminal;
    union {
        Tok tok;
        string name;
    }

    this(string s) {
        terminal = false;
        name = s;
    }
    this(Tok t) {
        terminal = true;
        tok = t;
    }

    string toString() {
        return terminal ? to!string(tok) : name;
    }

    int opCmp(Sym o) {
        if (terminal != o.terminal) { return terminal - o.terminal; }
        if (terminal) {
            mixin (simpleCmp("o", "tok"));
        } else {
            mixin (simpleCmp("o", "name"));
        }
    }
    bool opEquals(Sym o) {
        if (terminal != o.terminal) { return false; }
        return terminal ? tok == o.tok : name == o.name;
    }
}


template ParserGen(Token, Result, Tok, alias getTok,
        alias grammar, alias s, alias eof
        ) if (is(typeof(getTok(Token.init)) : Tok)) {

    alias Result delegate(StackItem[]) ReduceFun;

    struct Parser {
        State[] states;

        StackItem[] stack;
        size_t current;

        bool finished;
        Result[] results;

        void reset() {
            finished = false;
            results = [];
            stack = [];
            current = 0;
        }

        ReduceFun[string] reduction_table;

        this(ReduceFun[string] rfs) {
            populate_rules();
            populate_firsts();

            reduction_table = rfs;
            states = [State(s)];
            for (size_t i = 0; i < states.length; i += 1) {
                //writeln("i = ", i);
                foreach (set; states[i].items.groupByPostStart()) {
                    //writeln(set);
                    auto newstate = State(set.map!(a => a.next()).array());
                    auto index = states.countUntil(newstate);
                    if (index < 0) {
                        states ~= newstate;
                        index = states.length - 1;
                    }
                    auto start = set[0].post[0];
                    states[i].transitions ~= Transition(start,
                            cast(size_t)index);
                }
            }
        }

        void feed(Token token) {
            Tok t = getTok(token);
            foreach (item; states[current].reductions) {
                if (item.lookahead.canFind(t)) {
                    reduce(item);
                    feed(token);
                    return;
                }
            }
            shift(token);
        }

        void reduce(Item item) {
            auto to_remove = stack[$ - item.rule.length .. $];
            if (item.rule.length > 0) {
                writeln("reducing ", to_remove, " to ", item.orig);
            }
            assert (item.orig in reduction_table, item.orig ~ " not in table");
            auto result = reduction_table[item.orig](to_remove);
            stack = stack[0 .. $ - item.rule.length];
            stack ~= StackItem(item.orig, result);
            if (stack.length == 1 && item.orig == s) {
                yield();
            } else {
                runNFA();
            }
        }

        void shift(Token token) {
            //writeln("shift ", token);
            if (getTok(token) == eof) {
                finished = true;
                return;
            }
            stack ~= StackItem(token);
            runNFA();
        }

        void runNFA() {
            //writeln("running nfa...");
            current = 0;
            foreach (si; stack) {
                bool found;
                foreach (transition; states[current].transitions) {
                    if (transition.sym == si.sym) {
                        current = transition.next;
                        found = true;
                        break;
                    }
                }
                assert (found,
                        text("NO TRANSITION FOUND!",
                            " state = ", current,
                            " symbol = ", si,
                            " stack = ", stack
                            ));
            }
        }

        void yield() {
            results ~= stack[0].result;
            stack = [];
            current = 0;
        }
    }

    struct StackItem {
        bool terminal;
        private union {
            Token _token;
            struct {
                string _name;
                Result _result;
            }
        }
        ref Token token() @property { assert (terminal); return _token; }
        ref string name() @property { assert (!terminal); return _name; }
        ref Result result() @property { assert (!terminal); return _result; }

        this(Token tok) {
            terminal = true;
            _token = tok;
        }
        this(string s, Result res) {
            terminal = false;
            _name = s;
            _result = res;
        }

        string toString() {
            return terminal ? text(getTok(_token)) :_name;
        }
        Sym!Tok sym() @property {
            return terminal ? Sym!Tok(getTok(_token)) : Sym!Tok(_name);
        }
    }




    private struct Item {
        Rule!Tok* rule;

        Tok[] lookahead;
        Sym!Tok[] post;

        string orig() @property { return rule.name; }

        this(ref Rule!Tok r, Tok[] lah) {
            rule = &r;
            post = rule.syms;
            lookahead = lah;
        }

        Item next() {
            Item ret = this;
            ret.post.popFront();
            return ret;
        }
        Item without_lookahead() {
            auto ret = this;
            ret.lookahead = [];
            return ret;
        }

        string toString() {
            return format("%s -> * %(%s %) {%(%s %)}",
                    orig, post, lookahead);
        }
        bool opEquals(Item o) {
            return rule == o.rule && post.length == o.post.length
                && lookahead == o.lookahead;
        }

        int opCmp(Item o) {
            mixin (simpleCmp("o",
                        "rule.name", "rule.syms", "post.length", "lookahead"));
        }
    }

    private struct Transition {
        Sym!Tok sym;
        size_t next;

        string toString() { return text(sym, " -> ", next); }
    }

    private struct State {
        Item[] items;
        //size_t first_shift;
        Item[] reductions;
        Transition[] transitions;

        this(string start) {
            foreach (ref rule; get_rules(start)) { 
                items ~= Item(rule, [eof] ~ get_firsts(start));
            }
            expand_items();
        }
        this(Item[] _items) {
            items = _items;
            expand_items();
        }
        private void expand_items() {
            for (size_t i = 0; i < items.length; i += 1) {
                auto item = items[i];
                if (item.post.empty || item.post[0].terminal) {
                    continue;
                }
                auto f = item.post[0];
                foreach (ref rule; get_rules(f.name)) {
                    auto lookahead = item.post.length > 1 
                        ? get_firsts(item.post[1])
                        : item.lookahead;
                    auto it = Item(rule, lookahead);
                    if (!items.canFind(it)) {
                        items ~= it;
                    }
                }
            }

            merge_items();

            static bool by_post(Item a, Item b) {
                if (a.post.empty) {
                    return !b.post.empty;
                }
                if (b.post.empty) {
                    return false;
                }
                return a.post[0] < b.post[0];
            }
            items.sort!by_post();


            size_t first_shift;
            while (first_shift < items.length
                    && items[first_shift].post.empty) {
                first_shift += 1;
            }
            //writefln("Items post-post-sort:\n%(%s\n%)\n\n", items);
            //assert (0);
            reductions = items;
            reductions.length = first_shift;
        }

        void merge_items() {
            items.sort();
            //writefln("Items pre-merge:\n%(%s\n%)\n\n", items);
            int j;
            for (int i; i < items.length; i += 1) {
                if (i == j) {
                    continue;
                }
                if (items[i].without_lookahead == items[j].without_lookahead) {
                    items[j].lookahead ~= items[i].lookahead;
                    items[j].lookahead.make_set();
                } else {
                    j += 1;
                    items[j] = items[i];
                }
            }
            items = items[0 .. j+1];
            //writefln("Items post-merge:\n%(%s\n%)\n\n", items);
        }

        bool opEquals(State o) {
            return items == o.items;
        }
        string toString() {
            if (transitions.empty) {
                return format(" %(%s\n %)", items);
            } else {
                return format(" %(%s\n %)\n    %(%s\n    %)",
                        items, transitions);
            }
        }
    }

    Tok[][string] firsts;
    Tok[Tok.max] term_firsts;

    void populate_firsts() {
        writeln("populating firsts");
        foreach (rule; grammar) {
            if (rule.name in firsts) {
                continue;
            }
            firsts[rule.name] = generate_firsts(grammar, Sym!Tok(rule.name));
        }
        foreach (i; 0 .. Tok.max) {
            term_firsts[i] = cast(Tok)i;
        }
    }

    Tok[] get_firsts(string s) {
        return firsts[s];
    }

    Tok[] get_firsts(Sym!Tok sym) {
        if (sym.terminal) {
            return (&term_firsts[sym.tok])[0 .. 1];
        } else {
            return get_firsts(sym.name);
        }
    }

    Rule!Tok[][string] rules;

    void populate_rules() {
        foreach (rule; grammar) {
            if (rule.name in rules) {
                continue;
            }
            rules[rule.name] = .rules(grammar, rule.name);
        }
    }
    Rule!Tok[] get_rules(string s) {
        return rules[s];
    }

    auto generate_firsts(Rule, Sym)(Rule[] grammar, Sym sym) {
        alias typeof(sym.tok) Tok;
        static void firsts2(ref Tok[] ret, Rule[] grammar,
                Sym sym, ref string[] seen) {
            if (sym.terminal) {
                ret ~= sym.tok;
            } else {
                if (seen.canFind(sym.name)) {
                    return;
                }
                seen ~= sym.name;
                foreach (ref rule; get_rules(sym.name)) {
                    firsts2(ret, grammar, rule[0], seen);
                }
            }
        }
        Tok[] ret;
        string[] seen;
        firsts2(ret, grammar, sym, seen);
        ret.length += 1;
        ret.length -= 1;
        return ret.make_set();
    }
}

auto rules(Rule)(Rule[] grammar, string name) {
    assert (grammar.map!(a => a.name).canFind(name),
            "No rules with name " ~ name);
    //return grammar.zip(repeat(name))
    //    .filter!(a => a[0].name == a[1])()
    //    .map!(a => a[0]);
    Rule[] ret;
    foreach (rule; grammar) {
        if (rule.name == name) {
            ret ~= rule;
        }
    }
    ret.length += 1;
    ret.length -= 1;
    return ret;
}

struct SamePostStart(Item) {
    Item[] items;

    Item[] _front;
    Item[] front() @property {
        return _front;
    }
    void popFront() {
        while (!items.empty && items[0].post.empty) {
            items.popFront();
        }
        if (items.empty) {
            _front = [];
            return;
        }
        auto f = items[0].post[0];

        size_t i = 1;
        while (i < items.length && items[i].post[0] == f) {
            i += 1;
        }
        _front = items[0 .. i];
        items = items[i .. $];
    }
    bool empty() {
        return _front.empty && items.empty;
    }
}

SamePostStart!Item groupByPostStart(Item)(Item[] items) {
    SamePostStart!Item ret;
    ret.items = items;
    ret.popFront();
    return ret;
}


