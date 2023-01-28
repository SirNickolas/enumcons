module enumcons.type_system;

private nothrow pure @safe @nogc:

public struct unknownValue {
    string memberName;
}

/++
    Scan the enum for an `@unknownValue` annotation and return the member it points to. If there are
    no such annotations, return `void`. If multiple, produce a compilation error.
+/
template _typeBoundUnknownValue(E) {
    import std.traits: Unqual;

    // Process annotations of the enum itself.
    static foreach (uda; __traits(getAttributes, E)) {
        static assert(!is(Unqual!uda == unknownValue),
            "When attached to a whole enum, `@unknownValue()` should specify the name of its member"
        );
        static if (is(Unqual!(typeof(uda)) == unknownValue))
            enum _typeBoundUnknownValue = __traits(getMember, E, uda.memberName);
    }
    // Process annotations of the enum's members (2.082+).
    static foreach (memberName; __traits(allMembers, E))
        static foreach (uda; __traits(getAttributes, __traits(getMember, E, memberName))) {
            static assert(!is(Unqual!(typeof(uda)) == unknownValue),
                "When attached to a member, `@unknownValue` should be used without parentheses",
            );
            static if (is(Unqual!uda == unknownValue))
                enum _typeBoundUnknownValue = __traits(getMember, E, memberName);
        }
}

version (unittest) { // D <2.082 allows to attach attributes only to global enums.
    enum U0 { a, b, c }

    @unknownValue(`a`)
    enum U1 { a, b, c }

    @unknownValue(`c`)
    enum U2 { a, b }

    @unknownValue(`a`) @unknownValue(`b`)
    enum U3 { a, b }

    @unknownValue(`a`) @unknownValue(`a`)
    enum U4 { a, b }

    @unknownValue()
    enum U5 { a }

    @unknownValue
    enum U6 { a }
}

unittest {
    static assert(is(typeof(_typeBoundUnknownValue!U0) == void));
    static assert(_typeBoundUnknownValue!U1 == U1.a);
    static assert(!__traits(compiles, _typeBoundUnknownValue!U2));
    static assert(!__traits(compiles, _typeBoundUnknownValue!U3));
    static assert(!__traits(compiles, _typeBoundUnknownValue!U4));
    static assert(!__traits(compiles, _typeBoundUnknownValue!U5));
    static assert(!__traits(compiles, _typeBoundUnknownValue!U6));
}

static if (__VERSION__ >= 2_082)
unittest {
    mixin(q{
        enum A { @unknownValue a, b, c }
        enum B { @unknownValue(`a`) a }
        enum C { @unknownValue() a }
        enum D { @unknownValue @unknownValue a }
        enum E { @unknownValue a, @unknownValue b }

        @unknownValue(`a`)
        enum F { @unknownValue a }

        @unknownValue(`a`)
        enum G { a, @unknownValue b }
    });

    static assert(_typeBoundUnknownValue!A == A.a);
    static assert(!__traits(compiles, _typeBoundUnknownValue!B));
    static assert(!__traits(compiles, _typeBoundUnknownValue!C));
    static assert(!__traits(compiles, _typeBoundUnknownValue!D));
    static assert(!__traits(compiles, _typeBoundUnknownValue!E));
    static assert(!__traits(compiles, _typeBoundUnknownValue!F));
    static assert(!__traits(compiles, _typeBoundUnknownValue!G));
}

struct _HasSubtype(E) {
    long offset;
    bool allowDowncast;
    bool hasUnknownValue;
    long unknownValue;
}

package template declareSupertype(immutable(long)[ ] offsets, bool allowDowncast, subtypes...) {
    import std.traits: Unqual;
    import enumcons.utils: staticMapI;

    template typeProof(size_t i, alias enumOrValue) {
        static if (is(Unqual!enumOrValue E)) {
            alias unknownValue = _typeBoundUnknownValue!E;
            static if (is(typeof(unknownValue) == void))
                enum typeProof = _HasSubtype!E(offsets[i], allowDowncast);
            else
                enum _HasSubtype!E typeProof = {
                    offset: offsets[i],
                    allowDowncast: allowDowncast,
                    hasUnknownValue: true,
                    unknownValue: unknownValue,
                };
        } else {
            // The unknown value was specified explicitly. Do not even check whether `@unknownValue`
            // annotations are attached to the type correctly.
            enum _HasSubtype!(Unqual!(typeof(enumOrValue))) typeProof = {
                offset: offsets[i],
                allowDowncast: allowDowncast,
                hasUnknownValue: true,
                unknownValue: enumOrValue,
            };
        }
    }

    alias declareSupertype = staticMapI!(typeProof, subtypes);
}

unittest {
    enum A { a, b }
    enum B { c, d }

    alias proofs = declareSupertype!([0, 2], false, A, B.d);
    enum _HasSubtype!A proof0 = { offset: 0 };
    enum _HasSubtype!B proof1 = { offset: 2, hasUnknownValue: true, unknownValue: B.d };
    static assert(proofs[0] == proof0);
    static assert(proofs[1] == proof1);
}

package alias SubtypeInfo = _HasSubtype!void;

SubtypeInfo _calcSubtypeInfo(From, Mid)(_HasSubtype!Mid proof) {
    static if (is(From == Mid))
        return SubtypeInfo(
            proof.offset, proof.allowDowncast, proof.hasUnknownValue, proof.unknownValue,
        );
    else {
        auto result = _subtypeInfo!(From, Mid);
        result.offset += proof.offset;
        result.allowDowncast &= proof.allowDowncast;
        return result;
    }
}

/// Recursively search for `From` in `To`'s descendants and return the offset that needs to be
/// added to a value to convert it from `From` to `To`.
template _subtypeInfo(From, To) {
    // `_HasSubtype` is `private`, `declareSupertype` is `package` so we can assume they are
    // always constructed correctly. An enum cannot have duplicate members, therefore,
    // the relationship graph is actually a tree. And in a tree, there is a single path between
    // any two nodes. All things considered, `enum _subtypeInfo` below will be defined
    // at most once.
    static foreach (uda; __traits(getAttributes, To))
        static if (__traits(compiles, _calcSubtypeInfo!From(uda)))
            enum _subtypeInfo = _calcSubtypeInfo!From(uda);
}

package template subtypeInfo(From, To) {
    import std.traits: Unqual;

    static if (is(Unqual!From == Unqual!To))
        enum subtypeInfo = SubtypeInfo.init;
    else
        enum subtypeInfo = _subtypeInfo!(Unqual!From, Unqual!To);
}

version (unittest) { // D <2.082 allows to attach attributes only to global enums.
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
}

unittest {
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
