module enumcons.traits;

version (unittest) {
    import enumcons.def: Concat, ConcatInitLast, Merge, Unite;
    import enumcons.type_system: unknownValue;
}

private nothrow pure @safe @nogc:

public template isEnumSubtype(Sub, Super)
if (is(Sub == enum) && is(Super == enum) && __traits(isIntegral, Sub, Super)) {
    import enumcons.type_system: subtypeInfo;

    enum isEnumSubtype = __traits(compiles, subtypeInfo!(Sub, Super));
}

///
unittest {
    enum A { a, b }
    enum B { c, d }
    enum X { x }
    alias C = Concat!(A, B);

    static assert(isEnumSubtype!(A, C));
    static assert(isEnumSubtype!(A, A));
    static assert(isEnumSubtype!(C, C));
    static assert(isEnumSubtype!(X, X));

    static assert(!isEnumSubtype!(C, A));
    static assert(!isEnumSubtype!(A, B));
    static assert(!isEnumSubtype!(A, X));
    static assert(!isEnumSubtype!(C, X));
    static assert(!isEnumSubtype!(X, A));
    static assert(!isEnumSubtype!(X, C));

    static assert(!__traits(compiles, isEnumSubtype!(int, A)));
    static assert(!__traits(compiles, isEnumSubtype!(A, int)));
    static assert(!__traits(compiles, isEnumSubtype!(int, C)));
    static assert(!__traits(compiles, isEnumSubtype!(C, int)));
}

public template isEnumUpcastable(From, To) if (is(From == enum) && __traits(isIntegral, From, To)) {
    static if (is(From: To))
        enum isEnumUpcastable = true;
    else
        enum isEnumUpcastable = isEnumSubtype!(From, To);
}

///
unittest {
    enum A { a, b }
    enum B { c, d }
    enum X { x }
    alias C = Concat!(A, B);

    static assert(isEnumUpcastable!(A, C));
    static assert(isEnumUpcastable!(A, A));
    static assert(isEnumUpcastable!(C, C));
    static assert(isEnumUpcastable!(X, X));
    static assert(isEnumUpcastable!(A, int));
    static assert(isEnumUpcastable!(C, int));

    static assert(!isEnumUpcastable!(C, A));
    static assert(!isEnumUpcastable!(A, B));
    static assert(!isEnumUpcastable!(A, X));
    static assert(!isEnumUpcastable!(C, X));
    static assert(!isEnumUpcastable!(X, A));
    static assert(!isEnumUpcastable!(X, C));

    static assert(!__traits(compiles, isEnumUpcastable!(int, A)));
    static assert(!__traits(compiles, isEnumUpcastable!(int, C)));
}

public template isEnumDowncastable(From, To)
if (is(From == enum) && is(To == enum) && __traits(isIntegral, From, To)) {
    import std.traits: Unqual;
    import enumcons.type_system: subtypeInfo;

    static if (!is(Unqual!From == Unqual!To) && isEnumSubtype!(To, From))
        enum bool isEnumDowncastable = subtypeInfo!(To, From).allowDowncast;
    else
        enum isEnumDowncastable = false;
}

///
unittest {
    enum A { a, b }
    enum B { c, d }
    enum X { x }
    alias C = Concat!(A, B);

    static assert(isEnumDowncastable!(C, A));
    static assert(is(typeof(isEnumDowncastable!(C, A)) == bool));

    static assert(!isEnumDowncastable!(A, A));
    static assert(!isEnumDowncastable!(C, C));
    static assert(!isEnumDowncastable!(X, X));
    static assert(!isEnumDowncastable!(A, C));
    static assert(!isEnumDowncastable!(A, B));
    static assert(!isEnumDowncastable!(A, X));
    static assert(!isEnumDowncastable!(C, X));
    static assert(!isEnumDowncastable!(X, A));
    static assert(!isEnumDowncastable!(X, C));

    static assert(!__traits(compiles, isEnumDowncastable!(int, A)));
    static assert(!__traits(compiles, isEnumDowncastable!(A, int)));
    static assert(!__traits(compiles, isEnumDowncastable!(int, C)));
    static assert(!__traits(compiles, isEnumDowncastable!(C, int)));
}

///
unittest {
    enum A { a = 0 }
    enum B { b = 1 }
    alias U = Unite!(A, B);
    alias M = Merge!(A, B);
    alias M1 = Merge!A;

    static assert(isEnumDowncastable!(U, A));
    static assert(isEnumDowncastable!(M1, A));

    static assert(!isEnumDowncastable!(A, U));
    static assert(!isEnumDowncastable!(M, A));
    static assert(!isEnumDowncastable!(A, M));
    static assert(!isEnumDowncastable!(A, M1));
}

public template enumFallbackValue(From, To)
if (
    is(From == enum) && is(To == enum) && __traits(isIntegral, From, To) &&
    isEnumDowncastable!(From, To)
) {
    import enumcons.type_system: subtypeInfo;

    enum info = subtypeInfo!(To, From);
    static if (info.hasFallbackValue)
        enum enumFallbackValue = info.fallbackValue;
}

version (unittest) { // D <2.082 allows to attach attributes only to global enums.
    @unknownValue(`a`)
    enum U { b, a, c }
}

unittest {
    enum X { x, y }
    alias C = Concat!(U, X);

    static assert(enumFallbackValue!(C, U) == U.a);
    static assert(is(typeof(enumFallbackValue!(C, X)) == void));

    static assert(!__traits(compiles, enumFallbackValue!(U, X)));
    static assert(!__traits(compiles, enumFallbackValue!(X, U)));
    static assert(!__traits(compiles, enumFallbackValue!(U, C)));
    static assert(!__traits(compiles, enumFallbackValue!(X, C)));
}

unittest {
    enum A { d, e }
    enum B { f, g }
    alias C = Concat!(U.c, A);
    alias D = Concat!(B.f, C.b);

    static assert(enumFallbackValue!(C, U) == U.c);
    static assert(enumFallbackValue!(D, B) == B.f);
    static assert(enumFallbackValue!(D, C) == C.b);
    static assert(enumFallbackValue!(D, U) == U.c); // Not `U.b`.
    static assert(is(typeof(enumFallbackValue!(C, A)) == void));
    static assert(is(typeof(enumFallbackValue!(D, A)) == void));
}

template _isCallable(alias func) {
    import std.traits: isCallable;

    // Detection of callable templates is backported from recent versions of Phobos.
    static if (is(typeof(&func.opCall!())))
        enum _isCallable = isCallable!(typeof(&func.opCall!()));
    else static if (is(typeof(&func!())))
        enum _isCallable = isCallable!(typeof(&func!()));
    else
        enum _isCallable = isCallable!func;
}

// Not public because the format might change in the future.
package template prettyName(alias T: X!args, alias X, args...) {
    import std.array: join;
    import std.meta: staticMap;

    enum prettyName =
        __traits(identifier, X) ~ `!(` ~ [staticMap!(.prettyName, args)].join(`, `) ~ ')';
}

package template prettyName(alias x) {
    static if (is(typeof(x) == enum))
        enum prettyName = prettyName!(typeof(x)) ~ '.' ~ x.stringof;
    else static if (_isCallable!x)
        enum prettyName = __traits(identifier, x);
    else
        enum prettyName = x.stringof;
}

package enum prettyName(T) = T.stringof; // D <2.087.

unittest {
    enum A: short { a }
    enum B: short { b }
    enum C: short { c }
    enum D: ubyte { d }
    enum E: byte { e = 1 }
    template F(T, int x) {
        enum F { f }
    }

    alias Composed = Concat!(Merge!(ConcatInitLast!(A.a, B), C).b, Unite!(D, E), F!(E, 10).f);
    static assert(prettyName!Composed ==
        `_Enum!(concat, int, ` ~
            `_Enum!(merge, short, _Enum!(concatInitLast, short, A.a, B), C).b, ` ~
            `_Enum!(unite, int, D, E), ` ~
            `F!(E, 10).f` ~
        ')',
    );
}
