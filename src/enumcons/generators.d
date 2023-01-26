module enumcons.generators;

private nothrow pure @safe:

package struct GenResult {
    string code;
    immutable(long)[ ] offsets;
}

string _generateOne(E)(in string attrPrefix, long offset) {
    import std.conv: to;

    string result;
    static foreach (j, memberName; __traits(allMembers, E)) {{
        alias member = __traits(getMember, E, memberName);
        static if (__traits(getAttributes, member).length)
            result ~= attrPrefix ~ j.to!string ~ ' ';
        result ~= memberName ~ '=' ~ (offset + member).to!string ~ ',';
    }}
    return result;
}

unittest {
    enum E { b, c, a, d = -4, e, f = 10, g, h = 1 }

    assert(_generateOne!E(`@b0_`, 2) == `b=2,c=3,a=4,d=-2,e=-1,f=12,g=13,h=3,`);
}

static if (__VERSION__ >= 2_082)
unittest {
    mixin(q{enum E { f, a, @c b = -2, c, @(d, "") d, e = a }});

    assert(_generateOne!E(`@f0_`, 1) == `f=1,a=2,@f0_2 b=-1,c=0,@f0_4 d=1,e=2,`);
}

string _injectIndex(in string prefix, size_t i) {
    import std.conv: to;

    return '@' ~ prefix ~ i.to!string ~ '_';
}

package GenResult merge(enums...)(in string prefix) {
    import enumcons.utils: TypeOf;

    string code;
    static foreach (i, e; enums)
        code ~= _generateOne!(TypeOf!e)(prefix._injectIndex(i), 0);
    return GenResult(code, new long[enums.length]);
}

unittest {
    enum A { a, b, c }
    enum B { x, y = 2, z }

    assert(merge!(A, B)(`a`).code == `a=0,b=1,c=2,x=0,y=2,z=3,`);
    assert(merge!A(`a`).code == `a=0,b=1,c=2,`);
    assert(merge(`a`).code == ``);
}

static if (__VERSION__ >= 2_082)
unittest {
    mixin(q{
        enum A { a, @B c = -2, b = 4 }
        enum B { d = -10, e, @A f = 3 }
    });
    assert(merge!(A, B)(`a`).code == `a=0,@a0_1 c=-2,b=4,d=-10,e=-9,@a1_2 f=3,`);
}

struct _Point {
    long pos;
    bool closed;
}

enum _cmpPoints(_Point a, _Point b) = a.pos != b.pos ? a.pos < b.pos : a.closed < b.closed;

template _getPoints(e) {
    import std.meta: AliasSeq;

    static if (!is(e E))
        alias E = typeof(e);
    static if (long(E.min) <= long(E.max))
        alias _getPoints = AliasSeq!(_Point(E.min), _Point(E.max, true));
    else // Possible if `OriginalType!E == ulong`.
        alias _getPoints = AliasSeq!(_Point(long.min), _Point(E.max, true), _Point(E.min));
}

package template unite(enums...) {
    static if (enums.length) {
        import std.conv: to;
        import std.meta: staticMap, staticSort;

        alias events = staticSort!(_cmpPoints, staticMap!(_getPoints, enums));
        static foreach (j, p; events[1 .. $])
            static assert(p.closed != events[j].closed, // Must not have two `open` events in a row.
                "Enums' ranges overlap: value `" ~ p.pos.to!string ~
                "` is defined in multiple enums",
            );
    }
    alias unite = merge!enums;
}

unittest {
    enum A { a, b, c }
    enum B { x = 10, y, z }

    assert(unite!(A, B)(`a`).code == `a=0,b=1,c=2,x=10,y=11,z=12,`);
    assert(unite!A(`a`).code == `a=0,b=1,c=2,`);
    assert(unite(`a`).code == ``);
}

static if (__VERSION__ >= 2_082)
unittest {
    mixin(q{
        enum A { a, @B c = -2, b = 4 }
        enum B { d = -10, e, @A f = -3 }
    });
    assert(unite!(A, B)(`a`).code == `a=0,@a0_1 c=-2,b=4,d=-10,e=-9,@a1_2 f=-3,`);
}

unittest {
    enum WrapsAround: ulong { a = 0, b = long.max + 1 }
    enum A: ulong { x = 1, y = 2 }
    enum B: ulong { x = -2, y = 0 }
    enum C: ulong { x = -2, y = -1 }

    static assert(!__traits(compiles, unite!(A, WrapsAround)(`a`)));
    static assert(!__traits(compiles, unite!(B, WrapsAround)(`a`)));
    assert(unite!(C, WrapsAround)(`a`).code ==
        `x=18446744073709551614,y=18446744073709551615,a=0,b=9223372036854775808,`,
    );
}

unittest {
    enum NonPositive: long { a = 0, b = long.max + 1 }
    enum A: long { x = 1, y = 2 }
    enum B: long { x = -2, y = 0 }
    enum C: long { x = -2, y = -1 }

    assert(unite!(A, NonPositive)(`a`).code == `x=1,y=2,a=0,b=-9223372036854775808,`);
    static assert(!__traits(compiles, unite!(B, NonPositive)(`a`)));
    static assert(!__traits(compiles, unite!(C, NonPositive)(`a`)));
}

package GenResult concat(enums...)(in string prefix) {
    import std.exception: assumeUnique;

    string code;
    auto offsets = new long[enums.length + 1]; // `concatInitLast` needs one extra element.
    long offset;
    static foreach (i, e; enums) {{
        static if (!is(e E))
            alias E = typeof(e);
        static if (i)
            offset -= E.min;
        code ~= _generateOne!E(prefix._injectIndex(i), offset);
        offset += E.max + 1L;
        offsets[i + 1] = offset;
    }}
    return GenResult(code, (() @trusted => assumeUnique(offsets))());
}

unittest {
    enum A { a, b = -1, c, d }
    enum B { x, y = -1, z, w = z }

    assert(concat!(A, B)(`a`).code == `a=0,b=-1,c=0,d=1,x=3,y=2,z=3,w=3,`);
    assert(concat!A(`a`).code == `a=0,b=-1,c=0,d=1,`);
    assert(concat(`a`).code == ``);
}

static if (__VERSION__ >= 2_082)
unittest {
    mixin(q{
        enum A { a, @A b = -1, c, d }
        enum B { x, y = -1, @A z, @A @B w = z }
    });
    assert(concat!(A, B)(`a`).code == `a=0,@a0_1 b=-1,c=0,d=1,x=3,y=2,@a1_2 z=3,@a1_3 w=3,`);
}

package template concatInitLast(enums...) {
    static if (enums.length <= 1)
        alias concatInitLast = merge!enums;
    else
        GenResult concatInitLast(in string prefix) {
            import enumcons.utils: TypeOf;

            auto result = concat!(enums[0 .. $ - 1])(prefix);
            alias Last = TypeOf!(enums[$ - 1]);
            result.code = _generateOne!Last(
                prefix._injectIndex(enums.length - 1),
                result.offsets[$ - 1] - Last.min,
            ) ~ result.code;
            return result;
        }
}

unittest {
    enum A { a, b = -1, c, d }
    enum B { x, y = -1, z, w = z }

    assert(concatInitLast!(A, B)(`a`).code == `x=3,y=2,z=3,w=3,a=0,b=-1,c=0,d=1,`);
    assert(concatInitLast!A(`a`).code == `a=0,b=-1,c=0,d=1,`);
    assert(concatInitLast(`a`).code == ``);
}

static if (__VERSION__ >= 2_082)
unittest {
    mixin(q{
        enum A { a, @A b = -1, c, d }
        enum B { x, y = -1, @A z, @A @B w = z }
    });
    assert(
        concatInitLast!(A, B)(`a`).code == `x=3,y=2,@a1_2 z=3,@a1_3 w=3,a=0,@a0_1 b=-1,c=0,d=1,`,
    );
}
