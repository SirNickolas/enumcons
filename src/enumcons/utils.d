module enumcons.utils;

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
        import std.meta: AliasSeq;

        alias staticMapI = AliasSeq!();
        static foreach (i, arg; args)
            staticMapI = AliasSeq!(staticMapI, func!(i, arg));
    }
else // Simple but slow.
    package template staticMapI(alias func, args...) {
        template loop(tailArgs...) {
            import std.meta: AliasSeq;

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

package template isSupertypeOf(E) {
    enum isSupertypeOf(alias uda) = is(typeof(uda) == _HasSubtype!E);
}
