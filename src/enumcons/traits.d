module enumcons.traits;

version (unittest)
import enumcons.def: Concat, ConcatInitLast, Merge, Unite;

nothrow pure @safe @nogc:

template isEnumSubtype(Sub, Super)
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

template isEnumSafelyConvertible(From, To) if (is(From == enum) && __traits(isIntegral, From, To)) {
    static if (is(From: To))
        enum isEnumSafelyConvertible = true;
    else
        enum isEnumSafelyConvertible = isEnumSubtype!(From, To);
}

///
unittest {
    enum A { a, b }
    enum B { c, d }
    enum X { x }
    alias C = Concat!(A, B);

    static assert(isEnumSafelyConvertible!(A, C));
    static assert(isEnumSafelyConvertible!(A, A));
    static assert(isEnumSafelyConvertible!(C, C));
    static assert(isEnumSafelyConvertible!(X, X));
    static assert(isEnumSafelyConvertible!(A, int));
    static assert(isEnumSafelyConvertible!(C, int));

    static assert(!isEnumSafelyConvertible!(C, A));
    static assert(!isEnumSafelyConvertible!(A, B));
    static assert(!isEnumSafelyConvertible!(A, X));
    static assert(!isEnumSafelyConvertible!(C, X));
    static assert(!isEnumSafelyConvertible!(X, A));
    static assert(!isEnumSafelyConvertible!(X, C));

    static assert(!__traits(compiles, isEnumSafelyConvertible!(int, A)));
    static assert(!__traits(compiles, isEnumSafelyConvertible!(int, C)));
}

template isEnumPossiblyConvertible(From, To)
if (is(From == enum) && is(To == enum) && __traits(isIntegral, From, To)) {
    import std.traits: Unqual;
    import enumcons.type_system: subtypeInfo;

    static if (isEnumSubtype!(To, From) && !is(Unqual!From == Unqual!To))
        enum isEnumPossiblyConvertible = subtypeInfo!(To, From).allowDowncast;
    else
        enum isEnumPossiblyConvertible = false;
}

///
unittest {
    enum A { a, b }
    enum B { c, d }
    enum X { x }
    alias C = Concat!(A, B);

    static assert(isEnumPossiblyConvertible!(C, A));

    static assert(!isEnumPossiblyConvertible!(A, A));
    static assert(!isEnumPossiblyConvertible!(C, C));
    static assert(!isEnumPossiblyConvertible!(X, X));
    static assert(!isEnumPossiblyConvertible!(A, C));
    static assert(!isEnumPossiblyConvertible!(A, B));
    static assert(!isEnumPossiblyConvertible!(A, X));
    static assert(!isEnumPossiblyConvertible!(C, X));
    static assert(!isEnumPossiblyConvertible!(X, A));
    static assert(!isEnumPossiblyConvertible!(X, C));

    static assert(!__traits(compiles, isEnumPossiblyConvertible!(int, A)));
    static assert(!__traits(compiles, isEnumPossiblyConvertible!(A, int)));
    static assert(!__traits(compiles, isEnumPossiblyConvertible!(int, C)));
    static assert(!__traits(compiles, isEnumPossiblyConvertible!(C, int)));
}

///
unittest {
    enum A { a = 0 }
    enum B { b = 1 }
    alias U = Unite!(A, B);
    alias M = Merge!(A, B);
    alias M1 = Merge!A;

    static assert(isEnumPossiblyConvertible!(U, A));
    static assert(isEnumPossiblyConvertible!(M1, A));

    static assert(!isEnumPossiblyConvertible!(A, U));
    static assert(!isEnumPossiblyConvertible!(M, A));
    static assert(!isEnumPossiblyConvertible!(A, M));
    static assert(!isEnumPossiblyConvertible!(A, M1));
}

template canEnumHaveUnknownValue(From, To)
if (
    is(From == enum) && is(To == enum) && __traits(isIntegral, From, To) &&
    isEnumPossiblyConvertible!(From, To)
) {
    import enumcons.type_system: subtypeInfo;

    enum canEnumHaveUnknownValue = subtypeInfo!(To, From).hasUnknownValue;
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
