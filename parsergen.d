module parsergen;

import std.file, std.format;

import std.stdio, std.conv, std.typecons, std.exception;
import std.algorithm, std.range, std.array, std.typetuple, std.regex;
import std.datetime;

import stuff;

import lexer;

struct StackItem {
    bool terminal;
    Token token;
    string name;
    string result;

    Sym sym() @property {
        Sym ret;
        ret.terminal = terminal;
        if (terminal) {
            ret.tok = token.tok;
        } else {
            ret.name = name;
        }
        return ret;
    }

    this(Token tok) {
        terminal = true;
        token = tok;
    }
    this(string s, string res) {
        terminal = false;
        name = s;
        result = res;
    }

    string toString() {
        if (terminal) {
            return text(token.tok);
        } 
        return name;
    }
}

struct Sym {
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
            if (tok < o.tok) return -1;
            if (tok > o.tok) return 1;
            return 0;
        } else {
            if (name < o.name) return -1;
            if (name > o.name) return 1;
            return 0;
        }
    }
    bool opEquals(Sym o) {
        if (terminal != o.terminal) { return false; }
        return terminal ? tok == o.tok : name == o.name;
    }
}

struct Rule {
    string name;
    Sym[] syms;
    alias syms this;

    this(string s, Sym[] res) {
        name = s;
        syms = res;
    }

    bool opEquals(Rule o) {
        return name == o.name && syms == o.syms;
    }
    int opCmp(Rule o) {
        if (name < o.name) return -1;
        if (name > o.name) return 1;
        if (syms < o.syms) return -1;
        if (syms > o.syms) return 1;
        return 0;
    }
    string toString() {
        return text(name, " -> ", syms);
    }
}

Rule rule(Ts...)(Ts ts) {
    Sym[] ret;
    foreach (t; ts[1..$]) {
        ret ~= Sym(t);
    }
    return Rule(ts[0], ret);
}


struct Item {
    Rule rule;

    size_t r;
    Tok[] lookahead;

    string orig() @property { return rule.name; }
    Sym[] pre() @property { return rule[0..r]; }
    Sym[] post() @property { return rule[r..$]; }

    this(Rule r, Tok[] lah) {
        rule = r;
        lookahead = lah;
    }

    Item next() {
        Item ret = this;
        ret.r += 1;
        return ret;
    }
    Item without_lookahead() {
        auto ret = this;
        ret.lookahead = [];
        return ret;
    }

    string toString() {
        return format("%s -> %(%s %) * %(%s %) {%(%s %)}",
                orig, pre, post, lookahead);
    }
    bool opEquals(Item o) {
        return rule == o.rule && r == o.r
            && lookahead == o.lookahead;
    }

    int opCmp(Item o) {
        if (rule < o.rule) return -1;
        if (rule > o.rule) return 1;
        if (r < o.r) return -1;
        if (r > o.r) return 1;
        if (lookahead < o.lookahead) return -1;
        if (lookahead > o.lookahead) return 1;
        return 0;
    }
}


auto rules(Rule[] grammar, string name) {
    assert (grammar.map!(a => a.name).canFind(name),
            "No rules with name " ~ name);
    Rule[] ret;
    foreach (rule; grammar) {
        if (rule.name == name) {
            ret ~= rule;
        }
    }
    return ret;
}

T[] make_set(T)(ref T[] ts) {
    auto rest = ts.sort().uniq().copy(ts);
    ts = ts[0 .. $ - rest.length];
    return ts;
}

Tok[] firsts(Rule[] grammar, Sym sym) {
    static void firsts2(ref Tok[] ret, Rule[] grammar, Sym sym, string[] seen) {
        if (sym.terminal) {
            ret ~= sym.tok;
        } else {
            if (seen.canFind(sym.name)) {
                return;
            }
            seen ~= sym.name;
            foreach (rule; grammar.rules(sym.name)) {
                firsts2(ret, grammar, rule[0], seen);
            }
        }
    }
    Tok[] ret;
    string[] seen;
    firsts2(ret, grammar, sym, seen);
    return ret.make_set();
}

struct Transition {
    Sym sym;
    size_t next;

    string toString() { return text(sym, " -> ", next); }
}

struct State {
    Item[] items;
    size_t first_shift;
    Transition[] transitions;

    this(Rule[] grammar, string start, Tok eof) {
        foreach (rule; grammar.rules(start)) {
            items ~= Item(rule, [eof]);
        }
        expand_items(grammar);
    }
    this(Rule[] grammar, Item[] _items) {
        items = _items;
        expand_items(grammar);
    }
    private void expand_items(Rule[] grammar) {
        for (size_t i = 0; i < items.length; i += 1) {
            auto item = items[i];
            if (item.post.empty || item.post[0].terminal) {
                continue;
            }
            auto f = item.post[0];
            foreach (rule; grammar.rules(f.name)) {
                auto lookahead = item.post.length > 1 
                    ? grammar.firsts(item.post[1])
                    : item.lookahead;
                auto it = Item(rule, lookahead);
                if (!items.canFind(it)) {
                    items ~= it;
                }
            }
        }

        merge_items();

        static bool by_post(Item a, Item b) {
            return a.post < b.post;
        }
        items.sort!by_post();


        while (first_shift < items.length
                && items[first_shift].post.empty) {
            first_shift += 1;
        }
    }

    void merge_items() {
        items.sort();
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
    }

    Item[] reductions() @property {
        return items[0 .. first_shift];
    }
    Item[] shifts() @property {
        return items[first_shift .. $];
    }


    bool opEquals(State o) {
        return items == o.items;
    }
    string toString() {
        if (transitions.empty) {
            return format(" %(%s\n %)", items);
        } else {
            return format(" %(%s\n %)\n    %(%s\n    %)", items, transitions);
        }
    }
}


struct SamePostStart {
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
        //writeln("f == ", f);

        size_t i = 1;
        while (i < items.length && items[i].post[0] == f) {
            i += 1;
        }
        _front = items[0 .. i];
        items = items[i .. $];
    }

    bool empty() {
        return front.empty && items.empty;
    }
}

SamePostStart groupByPostStart(Item[] items) {
    SamePostStart ret;
    ret.items = items;
    ret.popFront();
    return ret;
}

alias string delegate(StackItem[]) RF;

struct Parser {
    State[] states;

    StackItem[] stack;
    size_t current;

    bool finished;
    StackItem result() {
        assert (finished);
        return stack[0];
    }

    string starting_name;

    RF[string] reduction_table;

    this(Rule[] grammar, string s, Tok eof, RF[string] rfs) {
        reduction_table = rfs;
        starting_name = s;
        states = [State(grammar, s, eof)];
        for (size_t i = 0; i < states.length; i += 1) {
            //writeln("i = ", i);
            foreach (set; states[i].items.groupByPostStart()) {
                //writeln(set);
                auto newstate = State(grammar, set.map!(a => a.next()).array());
                auto index = states.indexOf(newstate);
                if (index < 0) {
                    states ~= newstate;
                    index = states.length - 1;
                }
                auto start = set[0].post[0];
                states[i].transitions ~= Transition(start, cast(size_t)index);
            }
        }
    }

    void feed(Token token) {
        Tok t = token.tok;
        foreach (item; states[current].reductions) {
            if (item.lookahead.canFind(t)) {
                reduce(item);
                if (!finished) {
                    feed(token);
                }
                return;
            }
        }
        shift(token);
    }

    void reduce(Item item) {
        auto to_remove = stack[$ - item.rule.length .. $];
        if (item.rule.length > 1) {
            writeln("reducing ", to_remove, " to ", item.orig);
        }
        assert (item.orig in reduction_table, item.orig ~ " not in table");
        auto result = reduction_table[item.orig](to_remove);
        stack = stack[0 .. $ - item.rule.length];
        stack ~= StackItem(item.orig, result);
        if (item.orig == starting_name) {
            finished = true;
            writeln("finished!");
        } else {
            runNFA();
        }
    }
    
    void shift(Token token) {
        stack ~= StackItem(token);
        //writeln("shift ", token);
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
}
