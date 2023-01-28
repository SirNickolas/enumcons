module enumcons.utils;

package nothrow pure @safe @nogc:

public struct unknownValue {
    string memberName;
}

/// Like `typeof(x)`, but does nothing if `x` is already a type.
template TypeOf(alias x) {
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
mixin(q{
    template staticMapI(alias func, args...) {
        import std.meta: AliasSeq;

        alias staticMapI = AliasSeq!();
        static foreach (i, arg; args)
            staticMapI = AliasSeq!(staticMapI, func!(i, arg));
    }
});
else // Simple but slow.
    template staticMapI(alias func, args...) {
        import std.meta: AliasSeq;

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
