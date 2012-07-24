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

        ReduceFun[string] reduction_table;

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

        this(ReduceFun[string] rfs, State[] ss) {

            reduction_table = rfs;
            states = ss;
        }

        void feed(Token token) {
            Tok t = getTok(token);
            if (t != eof) {
                foreach (transition; states[current].transitions) {
                    if (!transition.sym.terminal) {
                        continue;
                    }
                    if (transition.sym.tok == t) {
                        shift(token);
                        return;
                    }
                }
            }
            foreach (item; states[current].nucleus) {
                if (item.post.empty && item.context.canFind(t)) {
                    reduce(item);
                    feed(token);
                    return;
                }
            }
            if (t == eof) {
                return;
            }
            writeln("Cannot find shift or reduction for ", token, "\n",
                            "stack = ", stack);
            assert (0);
        }

        void reduce(Item item) {
            auto to_remove = stack[$ - item.rule.length .. $];
            writeln("reducing ", to_remove, " to ", item.orig);
            Result result;
            if (item.orig in reduction_table) {
                result = reduction_table[item.orig](to_remove);
            } else if ("default_reduction" in reduction_table) {
                result = reduction_table["default_reduction"](to_remove);
            } else {
                assert (0, item.orig ~ " not in table and no default");
            }
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

    Parser make_parser(ReduceFun[string] rfs) {

        size_t[][Sym!Tok] successors;
        State[] states;

        size_t find_compatible_state(Sym!Tok prev, State newstate) {
            if (prev !in successors) { return states.length; }
            foreach (index; successors[prev]) {
                if (states_compatible(states[index], newstate)) {
                    return index;
                }
            }
            return states.length;
        }

        void propagate_context(size_t index, Item[] cset) {
            cset.sort();
            size_t[] H_ixs;
            foreach (i, ref item; states[index].nucleus) {
                if (cset.empty) { break; }
                if (item.without_context != cset.front.without_context) {
                    continue;
                }
                auto prev_length = item.context.length;
                //if (index == 1 && (item.post.empty || item.post.front ==
                //            Sym!Tok(Tok.add))) {
                //    static int wtf = 0;

                //    auto d = setDifference(cset.front.context,
                //            item.context);
                //    if (!d.empty) {
                //        wtf += 1;
                //        if (wtf == 30) {
                //            assert (0);
                //        }
                //        writefln("=========== Propagating =========== \n"
                //                ~"%s with {%(%s %)}", item,
                //                d);
                //    }
                //}
                item.context.extend(cset.front.context);
                if (item.context.length != prev_length) {
                    H_ixs ~= i;
                }
                prev_length = item.context.length;
                item.context.extend(cset.front.context);
                assert (prev_length == item.context.length);
                cset.popFront();
            }
            //auto H = H_ixs.map!(a => states[index].nucleus[a])();
            Item[] H;
            foreach (i; H_ixs) {
                H ~= states[index].nucleus[i];
            }

            auto items = expand_items(H);
            foreach (set; items.groupByPostStart()) {

                auto start = set[0].post[0];

                auto ts = states[index].transitions.find!"a.sym == b"(start);
                if (ts.empty) { continue; }

                foreach (ref item; set) {
                    item = item.next();
                }

                propagate_context(ts[0].next, set);
            }
        }

        void merge_states(size_t index, State newstate) {
            propagate_context(index, newstate.nucleus);
        }

        populate_rules();
        populate_firsts();

        states = [make_start_state()];

        for (size_t i = 0; i < states.length; i += 1) {
            //writeln("i = ", i);

            auto items = expand_items(states[i].nucleus);

            foreach (set; items.groupByPostStart()) {

                State newstate;
                newstate.nucleus = set.map!(a => a.next()).array();

                newstate.nucleus.sort();

                auto start = set[0].post[0];
                auto index = find_compatible_state(start, newstate);
                if (index == states.length) {
                    states ~= newstate;
                    successors[start] ~= index;
                } else {
                    merge_states(index, newstate);
                }
                states[i].transitions ~= Transition(start,
                        cast(size_t)index);
            }
        }

        return Parser(rfs, states);
    }

    private bool compatible_contexts(Item[] a, Item[] b, size_t i, size_t j) {
        // weakly compatible... D:
        return
            (   setIntersection(a[i].context, b[j].context).empty
             && setIntersection(a[j].context, b[i].context).empty)
            || !setIntersection(a[i].context, a[j].context).empty
            || !setIntersection(b[i].context, b[j].context).empty;
    }

    private bool states_compatible(ref State a, ref State b) {
        auto len = a.nucleus.length;
        if (len != b.nucleus.length) { return false; }
        foreach (i; 0 .. len) {
            if (a.nucleus[i].without_context
                    != b.nucleus[i].without_context) {
                return false;
            } 
        }
        for (int i; i < len - 1; i += 1) {
            for (int j = i+1; j < len; j += 1) {
                if (!compatible_contexts(a.nucleus, b.nucleus, i, j)) {
                    return false;
                }
            }
        }
        return true;
    }

    private State make_start_state() {
        State start;
        auto ctx = [eof];

        foreach (ref rule; get_rules(s)) {
            start.nucleus ~= Item(rule, ctx);
        }
        return start;
    }
    private Item[] expand_items(R)(R items_) {
        Item[] items = items_.array();
        for (size_t i = 0; i < items.length; i += 1) {
            auto item = items[i];
            if (item.post.empty || item.post[0].terminal) {
                continue;
            }
            auto f = item.post[0];
            foreach (ref rule; get_rules(f.name)) {
                auto context = item.post.length > 1
                    ? get_firsts(item.post[1])
                    : item.context;
                auto it = Item(rule, context);
                if (!items.canFind(it)) {
                    items ~= it;
                }
            }
        }

        if (items.empty) { return items; }

        items = merge_items(items);

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

        return items;
    }

    private Item[] merge_items(Item[] items) {
        items.sort();
        int j;
        for (int i = 1; i < items.length; i += 1) {
            if (i == j) {
                continue;
            }
            if (items[j].without_context == items[i].without_context) {
                items[j].context.extend(items[i].context);
            } else {
                j += 1;
                items[j] = items[i];
            }
        }
        return items[0 .. j+1];
    }


    private struct Item {
        Rule!Tok* rule;

        Tok[] context;
        Sym!Tok[] post;

        string orig() @property { return rule.name; }

        this(ref Rule!Tok r, Tok[] ctx) {
            rule = &r;
            post = rule.syms;
            context = ctx;
        }

        Item next() {
            Item ret = this;
            ret.post.popFront();
            return ret;
        }
        Item without_context() {
            auto ret = this;
            ret.context = [];
            return ret;
        }

        string toString() {
            return format("%s -> %(%s %) * %(%s %) {%(%s %)}",
                    orig, rule.syms[0 .. $ - post.length], post, context);
        }
        bool opEquals(Item o) {
            return rule == o.rule && post.length == o.post.length
                && context == o.context;
        }

        int opCmp(Item o) {
            mixin (simpleCmp("o",
                        "rule.name", "rule.syms", "post.length", "context"));
        }
    }

    private struct Transition {
        Sym!Tok sym;
        size_t next;

        string toString() { return text(sym, " -> ", next); }
    }

    private struct State {
        Item[] nucleus;
        Transition[] transitions;

        bool opEquals(State o) {
            return nucleus == o.nucleus;
        }
        string toString() {
            if (transitions.empty) {
                return format(" %(%s\n %)", nucleus);
            } else {
                return format(" %(%s\n %)\n    %(%s\n    %)",
                        nucleus, transitions);
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
        assert (s in rules, s ~ " not in firsts!");
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
        assert (s in rules, s ~ " not in rules!");
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


