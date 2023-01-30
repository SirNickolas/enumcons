module enumcons.conv;

import enumcons.traits;

version (unittest)
import enumcons.def: Concat;

pure @safe:

private @property bool _isU32(ulong value) nothrow @nogc {
    return value <= uint.max;
}

private @property bool _isI32(long value) nothrow @nogc {
    return value == cast(int)value;
}

pragma(inline, true)
To as(To, From)(From e) nothrow @nogc
if (is(From == enum) && __traits(isIntegral, From, To) && isEnumUpcastable!(From, To)) {
    static if (is(From: To))
        return e;
    else {
        import enumcons.type_system: subtypeInfo;

        enum long offset = subtypeInfo!(From, To).offset;
        enum lo = From.min + offset; // lo <= result <= hi
        enum hi = From.max + offset;
        static if (!offset)
            return cast(To)e; // Avoid excessive casting.
        else static if (To.sizeof <= 4 || (lo._isU32 && hi._isU32)) // Prefer `movzx` over `movsx`.
            return cast(To)(cast(uint)e + cast(uint)offset); // Add, then zero-extend or truncate.
        else static if (lo._isI32 && hi._isI32)
            return cast(To)(cast(int)e + cast(int)offset); // Add, then sign-extend.
        else
            return cast(To)(e + offset);
    }
}

nothrow @nogc unittest {
    enum A { a, b }
    enum B { c, d, e }
    alias C = Concat!(A, B);

    assert(A.a.as!C == C.a);
    assert(A.b.as!C == C.b);
    assert(B.c.as!C == C.c);
    assert(B.d.as!C == C.d);
    assert(B.e.as!C == C.e);
    static assert(!__traits(compiles, A.a.as!B));
    static assert(!__traits(compiles, C.a.as!A));
    static assert(!__traits(compiles, C.a.as!B));
    static assert(!__traits(compiles, C.d.as!A));
    static assert(!__traits(compiles, C.d.as!B));
}

pragma(inline, true)
private To _unsafeTo(To, From)(From e) nothrow @nogc {
    import enumcons.type_system: subtypeInfo;

    enum long offset = subtypeInfo!(To, From).offset;
    static if (!offset)
        return cast(To)e; // Avoid excessive casting.
    else static if (To.sizeof <= 4 || (To.min._isU32 && To.max._isU32)) // Prefer `movzx`.
        return cast(To)(cast(uint)e - cast(uint)offset); // Subtract, then zero-extend or truncate.
    else static if (To.min._isI32 && To.max._isI32)
        return cast(To)(cast(int)e - cast(int)offset); // Subtract, then sign-extend.
    else
        return cast(To)(e - offset);
}

pragma(inline, true)
bool is_(Sub, Super)(Super e) nothrow @nogc
if (
    is(Super == enum) && is(Sub == enum) && __traits(isIntegral, Super, Sub) &&
    isEnumDowncastable!(Super, Sub)
) {
    import enumcons.type_system: subtypeInfo;

    enum long first = Sub.min + subtypeInfo!(Sub, Super).offset;
    enum subRange = ulong(Sub.max) - ulong(Sub.min);
    static if (Sub.min != Sub.max) {
        static if (subRange._isU32)
            return cast(uint)e - cast(uint)first <= uint(subRange);
        else
            return e - first <= subRange;
    } else // An enum with the only member.
        static if (Super.sizeof > 4 && subRange._isU32)
            return cast(uint)e == cast(uint)first;
        else
            return e == cast(Super)first;
}

nothrow @nogc unittest {
    enum A { a = 4 }
    enum B { b }
    alias C = Concat!(A, B);

    assert(C.a.is_!A);
    assert(C.b.is_!B);
    assert(!C.a.is_!B);
    assert(!C.b.is_!A);
    static assert(!__traits(compiles, A.a.is_!B));
    static assert(!__traits(compiles, A.a.is_!C));
}

To to(To, From)(From e) nothrow @nogc
if (
    is(From == enum) && is(To == enum) && __traits(isIntegral, From, To) &&
    isEnumDowncastable!(From, To) && !is(typeof(enumFallbackValue!(From, To)) == void)
) {
    return e.is_!To ? e._unsafeTo!To : enumFallbackValue!(From, To);
}

nothrow @nogc unittest {
    enum A { a = 3, b }
    enum B { x, y }
    alias C = Concat!(A.a, B.y);

    assert(C.a.to!A == A.a);
    assert(C.b.to!A == A.b);
    assert(C.x.to!A == A.a);
    assert(C.y.to!A == A.a);

    assert(C.a.to!B == B.y);
    assert(C.b.to!B == B.y);
    assert(C.x.to!B == B.x);
    assert(C.y.to!B == B.y);
}

pragma(inline, true)
To assertTo(To, From)(From e) nothrow @nogc
if (
    is(From == enum) && is(To == enum) && __traits(isIntegral, From, To) &&
    isEnumDowncastable!(From, To)
)
in {
    assert(e.is_!To, '`' ~ prettyName!From ~ "` does not hold a value of `" ~ prettyName!To ~ '`');
}
do { return e._unsafeTo!To; }

nothrow @nogc unittest {
    enum A { a = 3 }
    enum B { b }
    alias C = Concat!(A, B);

    assert(C.a.assertTo!A == A.a);
    assert(C.b.assertTo!B == B.b);
}

version (D_Exceptions) {
    import std.conv: ConvException;

    class EnumConvException: ConvException {
        import std.exception: basicExceptionCtors;

        ///
        mixin basicExceptionCtors;
    }

    To tryTo(To, From)(From e)
    if (
        is(From == enum) && is(To == enum) && __traits(isIntegral, From, To) &&
        isEnumDowncastable!(From, To)
    ) {
        if (e.is_!To)
            return e._unsafeTo!To;
        enum msg = '`' ~ prettyName!From ~ "` does not hold a value of `" ~ prettyName!To ~ '`';
        throw new EnumConvException(msg);
    }

    unittest {
        import std.exception: assertThrown;

        enum A { a = 3 }
        enum B { b }
        alias C = Concat!(A, B);

        assert(C.a.tryTo!A == A.a);
        assert(C.b.tryTo!B == B.b);
        assertThrown!EnumConvException(C.a.tryTo!B);
        assertThrown!EnumConvException(C.b.tryTo!A);
    }
} else
    @disable To tryTo(To, From)(From)
    if (
        is(From == enum) && is(To == enum) && __traits(isIntegral, From, To) &&
        isEnumDowncastable!(From, To)
    );
