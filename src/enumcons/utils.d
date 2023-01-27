module enumcons.utils;

import std.meta: AliasSeq;

private nothrow pure @safe @nogc:

public struct unknownValue {
    string memberName;
}

/// Like `typeof(x)`, but does nothing if `x` is already a type.
package template TypeOf(alias x) {
    static if (is(x))
        alias TypeOf = x;
    else
        alias TypeOf = typeof(x);
}

unittest {
    enum E { a }

    static assert(is(TypeOf!E == E));
    static assert(is(TypeOf!(E.a) == E));
}

static if (__VERSION__ >= 2_095)
    package template staticMapI(alias func, args...) {
        alias staticMapI = AliasSeq!();
        static foreach (i, arg; args)
            staticMapI = AliasSeq!(staticMapI, func!(i, arg));
    }
else // Simple but slow.
    package template staticMapI(alias func, args...) {
        template loop(tailArgs...) {
            static if (tailArgs.length)
                alias loop = AliasSeq!(
                    func!(args.length - tailArgs.length, tailArgs[0]),
                    loop!(tailArgs[1 .. $]),
                );
            else
                alias loop = AliasSeq!();
        }

        alias staticMapI = loop!args;
    }

struct _HasSubtype(E) {
    long offset;
    bool allowDowncast;
}

package template declareSupertype(immutable(long)[ ] offsets, bool allowDowncast, subtypes...) {
    import std.traits: Unqual;

    enum udaFor(size_t i, alias sub) = _HasSubtype!(Unqual!(TypeOf!sub))(offsets[i], allowDowncast);
    alias declareSupertype = staticMapI!(udaFor, subtypes);
}

unittest {
    enum A { a, b }
    enum B { c, d }

    static assert(
        declareSupertype!([0, 2], false, A, B.d) == AliasSeq!(_HasSubtype!A(0), _HasSubtype!B(2)),
    );
}

package alias SubtypeInfo = _HasSubtype!void;

SubtypeInfo _calcSubtypeInfo(From, Mid)(_HasSubtype!Mid proof) {
    enum next = _subtypeInfo!(From, Mid);
    return SubtypeInfo(proof.offset + next.offset, proof.allowDowncast & next.allowDowncast);
}

/// Recursively search for `From` in `To`'s descendants and return the offset that needs to be
/// added to a value to convert it from `From` to `To`.
template _subtypeInfo(From, To) {
    static if (is(From == To))
        enum _subtypeInfo = SubtypeInfo(0, true); // Don't modify the value; allow downcasting.
    else {
        // `_HasSubtype` is `private`, `declareSupertype` is `package` so we can assume they are
        // always constructed correctly. An enum cannot have duplicate members, therefore,
        // the relationship graph is actually a tree. And in a tree, there is a single path between
        // any two nodes. All things considered, `enum _subtypeInfo` below will be defined
        // at most once.
        static foreach (uda; __traits(getAttributes, To))
            static if (__traits(compiles, _calcSubtypeInfo!From(uda)))
                enum _subtypeInfo = _calcSubtypeInfo!From(uda);
    }
}

package template subtypeInfo(From, To) {
    import std.traits: Unqual;

    enum subtypeInfo = _subtypeInfo!(Unqual!From, Unqual!To);
}

unittest {
    enum A { a, b }
    enum C { c }
    enum D { d }
    enum E { e, f }
    enum G { g }
    enum H { h, i, j }
    enum K { k, l }
    enum M { m }
    enum X;

    @declareSupertype!([0, 2], true, A, C)
    enum AC { a, b, c }

    @declareSupertype!([0, 3], true, AC, D)
    enum AD { a, b, c, d }

    @declareSupertype!([0, 1], true, G, H)
    enum GJ { g, h, i, j }

    @declareSupertype!([0, 2], true, E, GJ)
    enum EJ { e, f, g, h, i, j}

    @declareSupertype!([0, 6], true, EJ, K)
    enum EL { e, f, g, h, i, j, k, l }

    @declareSupertype!([0, 4, 12], true, AD, EL, M)
    enum AM { a, b, c, d, e, f, g, h, i, j, k, l, m }

    static assert(subtypeInfo!(A, AC).offset == 0);
    static assert(subtypeInfo!(C, AC).offset == 2);
    static assert(subtypeInfo!(AC, AD).offset == 0);
    static assert(subtypeInfo!(D, AD).offset == 3);
    static assert(subtypeInfo!(A, AD).offset == 0);
    static assert(subtypeInfo!(C, AD).offset == 2);
    static assert(subtypeInfo!(H, GJ).offset == 1);
    static assert(subtypeInfo!(H, EJ).offset == 3);
    static assert(subtypeInfo!(H, EL).offset == 3);
    static assert(subtypeInfo!(H, AM).offset == 7);
    static assert(subtypeInfo!(A, AM).offset == 0);
    static assert(subtypeInfo!(K, AM).offset == 10);

    static assert(subtypeInfo!(AM, AM).offset == 0);
    static assert(subtypeInfo!(X, X).offset == 0);

    static assert(!__traits(compiles, subtypeInfo!(AC, A)));
    static assert(!__traits(compiles, subtypeInfo!(A, C)));
    static assert(!__traits(compiles, subtypeInfo!(EJ, D)));
    static assert(!__traits(compiles, subtypeInfo!(EJ, E)));
    static assert(!__traits(compiles, subtypeInfo!(AD, EL)));

    static assert(!__traits(compiles, subtypeInfo!(AD, X)));
    static assert(!__traits(compiles, subtypeInfo!(X, AD)));
}
