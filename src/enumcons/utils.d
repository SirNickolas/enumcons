module enumcons.utils;

package nothrow pure @safe:

/// Like `typeof(x)`, but does nothing if `x` is already a type.
template TypeOf(alias x) {
    static if (is(x))
        alias TypeOf = x;
    else
        alias TypeOf = typeof(x);
}

@nogc unittest {
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

/++
    Generate D code that fixes enum declarations. You have to mix it in if your enums' members have
    user-defined attributes, otherwise D would resolve their identifiers in a wrong scope.

    This bug has been fixed in D 2.093. If compiled by this release or later, this function always
    returns `" "` (i.e., it is a no-op).
+/
public string fixEnumsUntilD2093(in char[ ][ ] enumNames...) {
    // Attributes on enum members are completely unsupported in D <2.082.
    static if (__VERSION__ < 2_082 || __VERSION__ >= 2_093)
        return ` `;
    else {
        // Not `Appender` because it is actually slower during CTFE.
        string result = ` `; // Just to be sure it won't glue to other tokens.
        foreach (name; enumNames) {
            result ~= `static foreach(_enumcons_member;__traits(allMembers,`;
            result ~= name;
            result ~= `)){static if(__traits(getAttributes,__traits(getMember,`;
            result ~= name;
            result ~= `,_enumcons_member)).length){}}`;
        }
        return result;
    }
}

unittest {
    static if (__VERSION__ >= 2_082)
        mixin(q{enum A { @A @A a, b, @A c }});
    else
        enum A { a, b, c }

    static if (__VERSION__ >= 2_082 && __VERSION__ < 2_093)
        assert(fixEnumsUntilD2093(`A`) ==
            ` static foreach(_enumcons_member;__traits(allMembers,A)){` ~
                `static if(` ~
                    `__traits(getAttributes,__traits(getMember,A,_enumcons_member)).length` ~
                `){}` ~
            `}`,
        );
    else
        assert(fixEnumsUntilD2093(`A`) == ` `);
    assert(fixEnumsUntilD2093() == ` `);
    static assert(__traits(compiles,  { mixin(fixEnumsUntilD2093(`A`)); }));
    static assert(!__traits(compiles, { mixin(fixEnumsUntilD2093(`A`) ~ `else { }`); }));
}
