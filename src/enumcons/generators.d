module enumcons.generators;

package nothrow pure @safe:

private string _generateOne(E)(in string attrPrefix, long offset) {
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

string _concat(enums...)(in string attrPrefix) {
    import std.conv: to;

    string result;
    long offset;
    static foreach (i, e; enums) {{
        static if (!is(e E))
            alias E = typeof(e);
        static if (i)
            offset -= E.min;
        result ~= _generateOne!E('@' ~ attrPrefix ~ i.to!string ~ '_', offset);
        offset += E.max + 1L;
    }}
    return result;
}

unittest {
    enum A { a, b = -1, c, d }
    enum B { x, y = -1, z, w = z }

    assert(_concat!(A, B)(`a`) == `a=0,b=-1,c=0,d=1,x=3,y=2,z=3,w=3,`);
    assert(_concat(`a`) == ``);
}

static if (__VERSION__ >= 2_082)
unittest {
    mixin(q{
        enum A { a, @A b = -1, c, d }
        enum B { x, y = -1, @A z, @A @B w = z }
    });
    assert(_concat!(A, B)(`a`) == `a=0,@a0_1 b=-1,c=0,d=1,x=3,y=2,@a1_2 z=3,@a1_3 w=3,`);
}

string _unite(enums...)(in string prefix) {
    import std.algorithm.sorting: sort;
    import std.conv: to;
    import std.typecons: Tuple;

    alias Point = Tuple!(long, bool);
    string result;
    Point[ ] events;
    static foreach (i, e; enums) {{
        static if (!is(e E))
            alias E = typeof(e);
        static if (long(E.min) > long(E.max)) // Possible if `OriginalType!E == ulong`.
            events ~= Point(long.min, false); // Initially open.
        events ~= Point(E.min, false);
        events ~= Point(E.max, true);
        result ~= _generateOne!E('@' ~ prefix ~ i.to!string ~ '_', 0);
    }}

    events.sort();
    foreach (j, p; events[1 .. $])
        assert(p[1] != events[j][1],
            "Enums' ranges overlap: value `" ~ p[0].to!string ~ "` is defined in multiple enums",
        );
    return result;
}

unittest {
    enum A { a, b, c }
    enum B { x = 10, y, z }

    assert(_unite!(A, B)(`a`) == `a=0,b=1,c=2,x=10,y=11,z=12,`);
}

static if (__VERSION__ >= 2_082)
unittest {
    mixin(q{
        enum A { a, @B c = -2, b = 4 }
        enum B { d = -10, e, @A f = -3 }
    });
    assert(_unite!(A, B)(`a`) == `a=0,@a0_1 c=-2,b=4,d=-10,e=-9,@a1_2 f=-3,`);
}
