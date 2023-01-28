module enumcons.conv;

import enumcons.traits;

version (unittest)
import enumcons.def: Concat;

pure @safe:

To as(To, From)(From e) nothrow @nogc
if (is(From == enum) && __traits(isIntegral, From, To) && isEnumSafelyConvertible!(From, To)) {
    static if (is(From: To))
        return e;
    else {
        import enumcons.type_system: subtypeInfo;

        enum long offset = subtypeInfo!(From, To).offset;
        static if (!offset)
            return cast(To)e; // To be sure it is optimized no matter how stupid the compiler is.
        else {
            enum a = From.min, c = a + offset;
            enum b = From.max, d = b + offset;
            enum ai = cast(int)a, ci = cast(int)c;
            enum bi = cast(int)b, di = cast(int)d;
            // Try to do 32-bit arithmetics when possible.
            static if (a == ai && b == bi && c == ci && d == di)
                return cast(To)(cast(int)e + int(offset));
            else static if (a == uint(ai) && b == uint(bi) && c == uint(ci) && d == uint(di))
                return cast(To)(cast(uint)e + uint(offset));
            else
                return cast(To)(e + offset);
        }
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

bool is_(Sub, Super)(Super e) nothrow @nogc
if (
    is(Sub == enum) && is(Super == enum) && __traits(isIntegral, Sub, Super) &&
    isEnumPossiblyConvertible!(Super, Sub)
) {
    import enumcons.type_system: subtypeInfo;

    enum long offset = subtypeInfo!(Sub, Super).offset + Sub.min;
    // TODO: Optimize.
    return e - offset <= ulong(Sub.max - Sub.min);
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
    isEnumPossiblyConvertible!(From, To) && canEnumHaveUnknownValue!(From, To)
) {
    import enumcons.type_system: subtypeInfo;

    enum info = subtypeInfo!(To, From);
    // TODO: Optimize.
    if (e.is_!To)
        return cast(To)(e - info.offset);
    return info.unknownValue;
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

To assertTo(To, From)(From e) nothrow @nogc
if (
    is(From == enum) && is(To == enum) && __traits(isIntegral, From, To) &&
    isEnumPossiblyConvertible!(From, To)
)
in {
    assert(e.is_!To, '`' ~ prettyName!From ~ "` does not hold a value of `" ~ prettyName!To ~ '`');
}
do {
    import enumcons.type_system: subtypeInfo;

    enum long offset = subtypeInfo!(To, From).offset;
    // TODO: Optimize.
    return cast(To)(e - offset);
}

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
        isEnumPossiblyConvertible!(From, To)
    ) {
        // TODO: Optimize.
        if (e.is_!To)
            return e.assertTo!To;
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
        isEnumPossiblyConvertible!(From, To)
    );
