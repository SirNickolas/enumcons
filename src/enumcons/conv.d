module enumcons.conv;

import enumcons.traits: isEnumSafelyConvertible;

pure @safe:

To as(To, From)(From e) nothrow @nogc if (isEnumSafelyConvertible!(From, To)) {
    static if (is(From: To))
        return e;
    else {
        import enumcons.utils: offsetForUpcast;

        enum long offset = offsetForUpcast!(From, To);
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
    import enumcons.def;

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
