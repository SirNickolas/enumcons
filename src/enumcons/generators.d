module enumcons.generators;

private nothrow pure @safe:

package struct GenResult {
    string code;
    immutable(long)[ ] offsets;
    bool allowDowncast;
}

string _generateOne(E)(in string attrPrefix, long offset) {
    import std.conv: to;
    import std.meta: Alias;

    string result;
    static foreach (j, memberName; __traits(allMembers, E)) {{
        alias member = Alias!(__traits(getMember, E, memberName)); // `Alias` for D <2.084.
        // Attributes on enum members are supported since 2.082.
        enum attrCount = __traits(getAttributes, member).length;
        static if (attrCount) {
            static if (__VERSION__ >= 2_092)
                result ~= attrPrefix ~ j.stringof ~ ' ';
            else {
                // In D >=2.082 <2.092, we have to attach attributes individually.
                foreach (k; 0 .. attrCount)
                    result ~= attrPrefix ~ j.stringof ~ k.to!string ~ size_t.init.stringof[1 .. $];
                result ~= ' ';
            }
        }

        result ~= memberName ~ '=' ~ (offset + member).to!string ~ ',';
    }}
    return result;
}

version (unittest) {
    version (D_LP64)
        string _tr(return in string s) {
            import std.exception: assumeWontThrow;
            import std.string: translate;

            return assumeWontThrow(s.translate(['u': "LU"]));
        }
    else
        string _tr(return in string s) @nogc { return s; }
}

unittest {
    enum E { b, c, a, d = -4, e, f = 10, g, h = 1 }

    assert(_generateOne!E(`@b0LU`, 2) == `b=2,c=3,a=4,d=-2,e=-1,f=12,g=13,h=3,`);
}

static if (__VERSION__ >= 2_082)
unittest {
    mixin(q{enum E { f, a, @E b = -2, c, d, @(E, "") e = a + 1 }});
    static assert(__traits(getAttributes, E.b).length); // D <2.093.
    static assert(__traits(getAttributes, E.e).length);

    static if (__VERSION__ >= 2_092)
        assert(_generateOne!E(`@f` ~ size_t.init.stringof, 1) ==
            _tr(`f=1,a=2,@f0u2u b=-1,c=0,d=1,@f0u5u e=3,`),
        );
    else
        assert(_generateOne!E(`@f` ~ size_t.init.stringof, 1) ==
            _tr(`f=1,a=2,@f0u2u0u b=-1,c=0,d=1,@f0u5u0u@f0u5u1u e=3,`),
        );
}

package GenResult merge(enums...)(in string prefix) {
    import enumcons.utils: TypeOf;

    string code;
    static foreach (i, e; enums)
        code ~= _generateOne!(TypeOf!e)('@' ~ prefix ~ i.stringof, 0);
    return GenResult(code, new long[enums.length], enums.length <= 1);
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
    static assert(__traits(getAttributes, A.c).length); // D <2.093.
    static assert(__traits(getAttributes, B.f).length);

    static if (__VERSION__ >= 2_092)
        assert(merge!(A, B)(`a`).code == _tr(`a=0,@a0u1u c=-2,b=4,d=-10,e=-9,@a1u2u f=3,`));
    else
        assert(merge!(A, B)(`a`).code == _tr(`a=0,@a0u1u0u c=-2,b=4,d=-10,e=-9,@a1u2u0u f=3,`));
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

package GenResult unite(enums...)(in string prefix) {
    static if (enums.length >= 2) {
        import std.conv: to;
        import std.meta: staticMap, staticSort;

        alias events = staticSort!(_cmpPoints, staticMap!(_getPoints, enums));
        static foreach (j, p; events[1 .. $])
            static assert(p.closed != events[j].closed, // Must not have two `open` events in a row.
                "Enums' ranges overlap: value `" ~ p.pos.to!string ~
                "` is defined in multiple enums",
            );
    }

    auto result = merge!enums(prefix);
    result.allowDowncast = true;
    return result;
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
    static assert(__traits(getAttributes, A.c).length); // D <2.093.
    static assert(__traits(getAttributes, B.f).length);

    static if (__VERSION__ >= 2_092)
        assert(unite!(A, B)(`a`).code == _tr(`a=0,@a0u1u c=-2,b=4,d=-10,e=-9,@a1u2u f=-3,`));
    else
        assert(unite!(A, B)(`a`).code == _tr(`a=0,@a0u1u0u c=-2,b=4,d=-10,e=-9,@a1u2u0u f=-3,`));
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
        code ~= _generateOne!E('@' ~ prefix ~ i.stringof, offset);
        offset += E.max + 1L;
        offsets[i + 1] = offset;
    }}
    return GenResult(code, (() @trusted => assumeUnique(offsets))(), true);
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
        enum B { x, y = -2, @A z, @A @B w = x + 1 }
    });
    static assert(__traits(getAttributes, A.b).length); // D <2.093.
    static assert(__traits(getAttributes, B.z).length);
    static assert(__traits(getAttributes, B.w).length);

    static if (__VERSION__ >= 2_092)
        assert(concat!(A, B)(`a`).code ==
            _tr(`a=0,@a0u1u b=-1,c=0,d=1,x=4,y=2,@a1u2u z=3,@a1u3u w=5,`),
        );
    else
        assert(concat!(A, B)(`a`).code ==
            _tr(`a=0,@a0u1u0u b=-1,c=0,d=1,x=4,y=2,@a1u2u0u z=3,@a1u3u0u@a1u3u1u w=5,`),
        );
}

package template concatInitLast(enums...) {
    static if (enums.length <= 1)
        alias concatInitLast = merge!enums;
    else
        GenResult concatInitLast(in string prefix) {
            import enumcons.utils: TypeOf;

            enum n = enums.length - 1;
            auto result = concat!(enums[0 .. n])(prefix);
            alias Last = TypeOf!(enums[n]);
            result.code = _generateOne!Last(
                '@' ~ prefix ~ n.stringof,
                result.offsets[n] - Last.min,
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
        enum B { x, y = -2, @A z, @A @B w = x + 1 }
    });
    static assert(__traits(getAttributes, A.b).length); // D <2.093.
    static assert(__traits(getAttributes, B.z).length);
    static assert(__traits(getAttributes, B.w).length);

    static if (__VERSION__ >= 2_092)
        assert(concatInitLast!(A, B)(`a`).code ==
            _tr(`x=4,y=2,@a1u2u z=3,@a1u3u w=5,a=0,@a0u1u b=-1,c=0,d=1,`),
        );
    else
        assert(concatInitLast!(A, B)(`a`).code ==
            _tr(`x=4,y=2,@a1u2u0u z=3,@a1u3u0u@a1u3u1u w=5,a=0,@a0u1u0u b=-1,c=0,d=1,`),
        );
}
