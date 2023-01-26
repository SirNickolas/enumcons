module enumcons.def;

import std.meta: allSatisfy, staticMap;
import enumcons.traits;
public import enumcons.traits: unknownValue;

private nothrow pure @safe:

// template Concat(...)
// template Unite(...)
// template Merge(...)
// source.as!Combined // Always succeeds. Don't forget to handle `Source == Combined`.
// combined.is_!Source // `true` if holds a member from `Source`.
// combined.to!Source // `Source._` if unrepresentable. Only if it is defined, of course.
// combined.assertTo!Source // `AssertError` if lossless conversion is not possible.
// combined.tryTo!Source // `ConvException` if lossless conversion is not possible.

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

@nogc unittest {
    enum E { b, c, a, d = -4, e, f = 10, g, h = 1 }

    static assert(_generateOne!E(`@b0_`, 2) == `b=2,c=3,a=4,d=-2,e=-1,f=12,g=13,h=3,`);
}

static if (__VERSION__ >= 2_082)
@nogc unittest {
    mixin(q{enum E { f, a, @c b = -2, c, @(d, "") d, e = a }});

    static assert(_generateOne!E(`@f0_`, 1) == `f=1,a=2,@f0_2 b=-1,c=0,@f0_4 d=1,e=2,`);
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

template _Enum(alias generateMembers, Base, enums...) {
    import std.algorithm.searching: maxElement;
    import std.traits: EnumMembers;

    static assert(!is(Base == enum),
        "Specifying another enum as a base type for your enum is currently unsupported. " ~
        "Use `std.traits.{CommonType, OriginalType}`",
    );
    // Choose the longest member as prefix to avoid name collision.
    enum prefix = [staticMap!(_memberNames, enums)].maxElement!q{a.length};
    // TODO: Drop `@unknownValue` attributes from source enums.
    static foreach (i, e; enums)
        static foreach (j, member; EnumMembers!(_TypeOf!e))
            static if (__traits(getAttributes, member).length)
                mixin(`alias `, prefix, i, '_', j, ` = __traits(getAttributes, member);`);
    mixin(
        `@(__traits(getAttributes, _TypeOf!(enums[$ - 1])))
        enum _Enum: Base {`, generateMembers!enums(prefix), '}'
    );
}

public template Concat(enums...)
if (__traits(isIntegral, enums) && allSatisfy!(_isEnumOrEnumMember, enums)) {
    // `enums.length >= 1` because `__traits(isIntegral)` would have returned `false` otherwise.
    alias Concat = _Enum!(_concat, _CommonType!enums, enums);
}

/// ditto
public template ConcatWithBase(Base, enums...)
if (enums.length && __traits(isIntegral, Base, enums) && allSatisfy!(_isEnumOrEnumMember, enums)) {
    alias ConcatWithBase = _Enum!(_concat, Base, enums);
}

///
@nogc unittest {
    @unknownValue(`_`) // All versions of D.
    enum Color {
        /+@unknownValue+/ _, // 2.082+
        red,
        green,
        blue,
    }

    enum MoreColors {
        orange,
        cyan,
        magenta,
        purple,
        grey,
        gray = grey,
    }

    alias ExtendedColor = Concat!(Color, MoreColors);

    static assert(is(ExtendedColor == enum));
    static assert(ExtendedColor.orange == Color.max + 1);
    static assert(ExtendedColor.purple == ExtendedColor.cyan + 2);
    static assert(ExtendedColor.grey == ExtendedColor.gray);
    static assert(int(ExtendedColor.min) == Color.min);
    static assert(int(ExtendedColor.init) == Color.init);
}

/// Like `ConcatWithBase`, except that the resulting enum's `.init` value will be that of the last
/// passed argument, not first. In every other aspect, including the numbering scheme, they are
/// exactly the same.
version (none)
public template ConcatInitLast(enums...)
if (__traits(isIntegral, enums) && allSatisfy!(_isEnumOrEnumMember, enums)) {
    // `enums.length >= 1` because `__traits(isIntegral)` would have returned `false` otherwise.
    alias ConcatInitLast = _Enum!(_concatInitLast, _CommonType!enums, enums);
}

/// ditto
version (none)
public template ConcatWithBaseInitLast(Base, enums...)
if (enums.length && __traits(isIntegral, Base, enums) && allSatisfy!(_isEnumOrEnumMember, enums)) {
    alias ConcatWithBaseInitLast = _Enum!(_concatInitLast, Base, enums);
}

///
version (none)
@nogc unittest {
    enum A { a0, a1 }
    enum B { b0, b1 }

    alias C = ConcatInitLast!(A, B);
    static assert(C.init == C.b0);
    static assert(C.a0 == 0);
    static assert(C.a1 == 1);
    static assert(C.b0 == 2);
    static assert(C.b1 == 3);

    alias D = ConcatInitLast!(A, B.b1);
    // `b1` does not become `.init`; it becomes `@unknownValue`.
    static assert(D.init == B.b0);
}

public template Unite(enums...)
if (__traits(isIntegral, enums) && allSatisfy!(_isEnumOrEnumMember, enums)) {
    // `enums.length >= 1` because `__traits(isIntegral)` would have returned `false` otherwise.
    alias Unite = _Enum!(_unite, _CommonType!enums, enums);
}

/// ditto
public template UniteWithBase(Base, enums...)
if (enums.length && __traits(isIntegral, Base, enums) && allSatisfy!(_isEnumOrEnumMember, enums)) {
    alias UniteWithBase = _Enum!(_unite, Base, enums);
}

///
@nogc unittest {
    enum A { a = 1, b = 2, c = 10 }
    enum B { x = 1000, y }
    alias C = Unite!(A, B);

    static assert(is(C == enum));
    static assert(C.a == 1);
    static assert(C.b == 2);
    static assert(C.c == 10);
    static assert(C.x == 1000);
    static assert(C.y == 1001);
    static assert(C.init == C.a);
}

///
@nogc unittest {
    enum A { a = 1, b = 2 }
    enum B { x = 3, y = 1 }

    static assert(int(A.a) == B.y);
    static assert(!is(Unite!(A, B)));
}

///
@nogc unittest {
    enum A { a = 1, b = 10 }
    enum B { x = 4, y, z }

    // Despite the fact they have no common members, uniting them is still forbidden.
    // If it was allowed, `is_` could not be implemented effeciently.
    static assert(!is(Unite!(A, B)));
}
