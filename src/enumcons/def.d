module enumcons.def;

import std.meta: allSatisfy, staticMap;
import enumcons.generators;
import enumcons.traits;
public import enumcons.traits: unknownValue;

nothrow pure @safe @nogc:

// template Concat(...)
// template Unite(...)
// template Merge(...)
// source.as!Combined // Always succeeds. Don't forget to handle `Source == Combined`.
// combined.is_!Source // `true` if holds a member from `Source`.
// combined.to!Source // `Source._` if unrepresentable. Only if it is defined, of course.
// combined.assertTo!Source // `AssertError` if lossless conversion is not possible.
// combined.tryTo!Source // `ConvException` if lossless conversion is not possible.

private template _Enum(alias generateMembers, Base, enums...) {
    import std.algorithm.searching: maxElement;
    import std.traits: EnumMembers;

    static assert(!is(Base == enum),
        "Specifying another enum as a base type for your enum is currently unsupported. " ~
        "Use `std.traits.{CommonType, OriginalType}`",
    );
    // Choose the longest member as prefix to avoid name collision.
    enum prefix = [staticMap!(_memberNames, enums)].maxElement!q{a.length};
    // TODO: Drop `@unknownValue` attributes from source enums.
    static foreach (i, e; enums)
        static foreach (j, member; EnumMembers!(_TypeOf!e))
            static if (__traits(getAttributes, member).length)
                mixin(`alias `, prefix, i, '_', j, ` = __traits(getAttributes, member);`);
    mixin(
        `@(__traits(getAttributes, _TypeOf!(enums[$ - 1])))
        enum _Enum: Base {`, generateMembers!enums(prefix), '}'
    );
}

template Concat(enums...)
if (__traits(isIntegral, enums) && allSatisfy!(_isEnumOrEnumMember, enums)) {
    // `enums.length >= 1` because `__traits(isIntegral)` would have returned `false` otherwise.
    alias Concat = _Enum!(_concat, _CommonType!enums, enums);
}

/// ditto
template ConcatWithBase(Base, enums...)
if (enums.length && __traits(isIntegral, Base, enums) && allSatisfy!(_isEnumOrEnumMember, enums)) {
    alias ConcatWithBase = _Enum!(_concat, Base, enums);
}

///
unittest {
    @unknownValue(`_`) // All versions of D.
    enum Color {
        /+@unknownValue+/ _, // 2.082+
        red,
        green,
        blue,
    }

    enum MoreColors {
        orange,
        cyan,
        magenta,
        purple,
        grey,
        gray = grey,
    }

    alias ExtendedColor = Concat!(Color, MoreColors);

    static assert(is(ExtendedColor == enum));
    static assert(ExtendedColor.orange == Color.max + 1);
    static assert(ExtendedColor.purple == ExtendedColor.cyan + 2);
    static assert(ExtendedColor.grey == ExtendedColor.gray);
    static assert(int(ExtendedColor.min) == Color.min);
    static assert(int(ExtendedColor.init) == Color.init);
}

/// Like `ConcatWithBase`, except that the resulting enum's `.init` value will be that of the last
/// passed argument, not first. In every other aspect, including the numbering scheme, they are
/// exactly the same.
version (none)
template ConcatInitLast(enums...)
if (__traits(isIntegral, enums) && allSatisfy!(_isEnumOrEnumMember, enums)) {
    // `enums.length >= 1` because `__traits(isIntegral)` would have returned `false` otherwise.
    alias ConcatInitLast = _Enum!(_concatInitLast, _CommonType!enums, enums);
}

/// ditto
version (none)
template ConcatWithBaseInitLast(Base, enums...)
if (enums.length && __traits(isIntegral, Base, enums) && allSatisfy!(_isEnumOrEnumMember, enums)) {
    alias ConcatWithBaseInitLast = _Enum!(_concatInitLast, Base, enums);
}

///
version (none)
unittest {
    enum A { a0, a1 }
    enum B { b0, b1 }

    alias C = ConcatInitLast!(A, B);
    static assert(C.init == C.b0);
    static assert(C.a0 == 0);
    static assert(C.a1 == 1);
    static assert(C.b0 == 2);
    static assert(C.b1 == 3);

    alias D = ConcatInitLast!(A, B.b1);
    // `b1` does not become `.init`; it becomes `@unknownValue`.
    static assert(D.init == B.b0);
}

template Unite(enums...)
if (__traits(isIntegral, enums) && allSatisfy!(_isEnumOrEnumMember, enums)) {
    // `enums.length >= 1` because `__traits(isIntegral)` would have returned `false` otherwise.
    alias Unite = _Enum!(_unite, _CommonType!enums, enums);
}

/// ditto
template UniteWithBase(Base, enums...)
if (enums.length && __traits(isIntegral, Base, enums) && allSatisfy!(_isEnumOrEnumMember, enums)) {
    alias UniteWithBase = _Enum!(_unite, Base, enums);
}

///
unittest {
    enum A { a = 1, b = 2, c = 10 }
    enum B { x = 1000, y }
    alias C = Unite!(A, B);

    static assert(is(C == enum));
    static assert(C.a == 1);
    static assert(C.b == 2);
    static assert(C.c == 10);
    static assert(C.x == 1000);
    static assert(C.y == 1001);
    static assert(C.init == C.a);
}

///
unittest {
    enum A { a = 1, b = 2 }
    enum B { x = 3, y = 1 }

    static assert(int(A.a) == B.y);
    static assert(!is(Unite!(A, B)));
}

///
unittest {
    enum A { a = 1, b = 10 }
    enum B { x = 4, y, z }

    // Despite the fact they have no common members, uniting them is still forbidden.
    // If it was allowed, `is_` could not be implemented effeciently.
    static assert(!is(Unite!(A, B)));
}
