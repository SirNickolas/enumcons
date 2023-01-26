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
}

package template declareSupertype(immutable(long)[ ] offsets, subtypes...) {
    enum udaFor(size_t i, alias sub) = _HasSubtype!(TypeOf!sub)(offsets[i]);
    alias declareSupertype = staticMapI!(udaFor, subtypes);
}

unittest {
    enum A { a, b }
    enum B { c, d }

    static assert(
        declareSupertype!([0, 2], A, B.d) == AliasSeq!(_HasSubtype!A(0), _HasSubtype!B(2)),
    );
}

long _getOffsetForUpcast(From, Mid)(_HasSubtype!Mid proof) {
    return proof.offset + _offsetForUpcast!(From, Mid);
}

/// Recursively search for `From` in `To`'s descendants and return the offset that needs to be
/// added to a value to convert it from `From` to `To`.
template _offsetForUpcast(From, To) {
    static if (is(From == To))
        enum _offsetForUpcast = 0L; // Don't need to modify the value.
    else {
        // `_HasSubtype` is `private`, `declareSupertype` is `package` so we can assume they are
        // always assigned correctly. An enum cannot have duplicate members, therefore,
        // the relationship graph is actually a tree. And in a tree, there is a single path between
        // any two nodes. All things considered, `enum _offsetForUpcast` below will be defined
        // at most once.
        static foreach (uda; __traits(getAttributes, To))
            static if (__traits(compiles, _getOffsetForUpcast!From(uda)))
                enum _offsetForUpcast = _getOffsetForUpcast!From(uda);
    }
}

package template offsetForUpcast(From, To) {
    import std.traits: Unqual;

    enum long offsetForUpcast = _offsetForUpcast!(Unqual!From, Unqual!To);
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

    @declareSupertype!([0, 2], A, C)
    enum AC { a, b, c }

    @declareSupertype!([0, 3], AC, D)
    enum AD { a, b, c, d }

    @declareSupertype!([0, 1], G, H)
    enum GJ { g, h, i, j }

    @declareSupertype!([0, 2], E, GJ)
    enum EJ { e, f, g, h, i, j}

    @declareSupertype!([0, 6], EJ, K)
    enum EL { e, f, g, h, i, j, k, l }

    @declareSupertype!([0, 4, 12], AD, EL, M)
    enum AM { a, b, c, d, e, f, g, h, i, j, k, l, m }

    static assert(offsetForUpcast!(A, AC) == 0);
    static assert(offsetForUpcast!(C, AC) == 2);
    static assert(offsetForUpcast!(AC, AD) == 0);
    static assert(offsetForUpcast!(D, AD) == 3);
    static assert(offsetForUpcast!(A, AD) == 0);
    static assert(offsetForUpcast!(C, AD) == 2);
    static assert(offsetForUpcast!(H, GJ) == 1);
    static assert(offsetForUpcast!(H, EJ) == 3);
    static assert(offsetForUpcast!(H, EL) == 3);
    static assert(offsetForUpcast!(H, AM) == 7);
    static assert(offsetForUpcast!(A, AM) == 0);
    static assert(offsetForUpcast!(K, AM) == 10);

    static assert(offsetForUpcast!(AM, AM) == 0);
    static assert(offsetForUpcast!(X, X) == 0);

    static assert(!__traits(compiles, offsetForUpcast!(AC, A)));
    static assert(!__traits(compiles, offsetForUpcast!(A, C)));
    static assert(!__traits(compiles, offsetForUpcast!(EJ, D)));
    static assert(!__traits(compiles, offsetForUpcast!(EJ, E)));
    static assert(!__traits(compiles, offsetForUpcast!(AD, EL)));

    static assert(!__traits(compiles, offsetForUpcast!(AD, X)));
    static assert(!__traits(compiles, offsetForUpcast!(X, AD)));
}

package template isSupertypeOf(E) {
    enum isSupertypeOf(alias uda) = is(typeof(uda) == _HasSubtype!E);
}
