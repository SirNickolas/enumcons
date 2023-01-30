module enumcons.utils;

import std.algorithm.mutation: SwapStrategy;
import std.range.primitives;
import std.typecons: Flag;

package:

/// Like `typeof(x)`, but does nothing if `x` is already a type.
template TypeOf(alias x) {
    static if (is(x))
        alias TypeOf = x;
    else
        alias TypeOf = typeof(x);
}

nothrow pure @safe @nogc unittest {
    enum E { a }

    static assert(is(TypeOf!E == E));
    static assert(is(TypeOf!(E.a) == E));
}

/// Like `std.typecons.Tuple` but stripped of all advanced features to keep compilation fast.
struct Tuple(Types...) {
    Types expand;

    alias expand this;
}

Flag!name yesNo(string name)(bool value) nothrow pure @safe @nogc {
    return cast(Flag!name)value;
}

/++
    Generate D code that fixes enum declarations. You have to mix it in if your enums' members have
    user-defined attributes, otherwise D would resolve their identifiers in a wrong scope.

    This bug has been fixed in D 2.093. If compiled by this release or later, this function always
    returns `" "` (i.e., it is a no-op).
+/
public string fixEnumsUntilD2093(in char[ ][ ] enumNames...) nothrow pure @safe {
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

nothrow pure @safe unittest {
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

private R _sort(alias less, R)(R input, R tmp)
in { assert(tmp.length >= input.length); }
do {
    import std.algorithm.mutation: swap;
    import std.algorithm.sorting: merge;
    import std.functional: binaryFun;

    const n = input.length;
    if (n <= 1)
        return input;

    // Ping-pong bottom-up merge sort (stable).
    for (size_t i = 1; i < n; i += 2) // Handle the first iteration manually.
        if (binaryFun!less(input[i], input[i - 1]))
            swap(input[i - 1], input[i]);

    R source = input, target = tmp[0 .. n];
    size_t chunk = 2, limit = n - 1;
    for (size_t pair = 4; pair < n; chunk = pair, pair <<= 1, swap(source, target)) {
        limit -= chunk;
        size_t i;
        do
            foreach (x; merge!less(source[i .. i + chunk], source[i + chunk .. i + pair]))
                target[i++] = x; // `std.algorithm.mutation.copy` is slower during CTFE.
        while (i < limit);
        if (i + chunk < n)
            foreach (x; merge!less(source[i .. i + chunk], source[i + chunk .. n]))
                target[i++] = x;
        else
            target[i .. n] = source[i .. n];
    }

    limit = 0;
    foreach (x; merge!less(source[0 .. chunk], source[chunk .. n]))
        target[limit++] = x;
    return target;
}

/// Like `std.algorithm.sorting.sort` but works at CTFE.
public R sort(alias less = q{a < b}, SwapStrategy ss = SwapStrategy.unstable, R)(R input, R tmp)
if (hasAssignableElements!R && isRandomAccessRange!R && hasSlicing!R && hasLength!R) {
    return _sort!less(input, tmp);
}
