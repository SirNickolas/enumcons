module enumcons.def;

import std.meta: allSatisfy;
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
    import std.meta: staticMap;
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
        `@(staticMap!(_declareSupertypeOf, enums))
        @(__traits(getAttributes, _TypeOf!(enums[$ - 1])))
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

    static assert(isEnumSafelyConvertible!(Color, ExtendedColor));
    static assert(isEnumSafelyConvertible!(MoreColors, ExtendedColor));
    static assert(!isEnumSafelyConvertible!(ExtendedColor, Color));
    static assert(!isEnumSafelyConvertible!(ExtendedColor, MoreColors));
}

/// Like `ConcatWithBase`, except that the resulting enum's `.init` value will be that of the last
/// passed argument, not first. In every other aspect, including the numbering scheme, they are
/// exactly the same.
template ConcatInitLast(enums...)
if (__traits(isIntegral, enums) && allSatisfy!(_isEnumOrEnumMember, enums)) {
    // `enums.length >= 1` because `__traits(isIntegral)` would have returned `false` otherwise.
    alias ConcatInitLast = _Enum!(_concatInitLast, _CommonType!enums, enums);
}

/// ditto
template ConcatWithBaseInitLast(Base, enums...)
if (enums.length && __traits(isIntegral, Base, enums) && allSatisfy!(_isEnumOrEnumMember, enums)) {
    alias ConcatWithBaseInitLast = _Enum!(_concatInitLast, Base, enums);
}

///
unittest {
    enum A { a0, a1 }
    enum B { b0, b1 }

    alias C = ConcatInitLast!(A, B);
    static assert(C.init == C.b0);
    static assert(C.a0 == 0);
    static assert(C.a1 == 1);
    static assert(C.b0 == 2);
    static assert(C.b1 == 3);

    static assert(isEnumSafelyConvertible!(A, C));
    static assert(isEnumSafelyConvertible!(B, C));
    static assert(!isEnumSafelyConvertible!(C, A));
    static assert(!isEnumSafelyConvertible!(C, B));

    alias D = ConcatInitLast!(A, B.b1);
    // `b1` does not become `.init`; it becomes `@unknownValue`.
    static assert(D.init == D.b0);
    static assert(int(D.a0) == A.a0);
    static assert(int(D.b0) > B.b0);
    static assert(D.b0 == A.a1 + 1);
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

    static assert(isEnumSafelyConvertible!(A, C));
    static assert(isEnumSafelyConvertible!(B, C));
    static assert(!isEnumSafelyConvertible!(C, A));
    static assert(!isEnumSafelyConvertible!(C, B));
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

template Merge(enums...)
if (__traits(isIntegral, enums) && allSatisfy!(_isEnumOrEnumMember, enums)) {
    // `enums.length >= 1` because `__traits(isIntegral)` would have returned `false` otherwise.
    alias Merge = _Enum!(_merge, _CommonType!enums, enums);
}

/// ditto
template MergeWithBase(Base, enums...)
if (enums.length && __traits(isIntegral, Base, enums) && allSatisfy!(_isEnumOrEnumMember, enums)) {
    alias MergeWithBase = _Enum!(_merge, Base, enums);
}

///
unittest {
    enum A { a, b, c }
    enum B { x = 1, y, z }
    alias C = Merge!(A, B);

    static assert(is(C == enum));
    static assert(C.a == 0);
    static assert(C.b == 1);
    static assert(C.c == 2);
    static assert(C.x == C.b);
    static assert(C.y == C.c);
    static assert(C.z == 3);
    static assert(C.init == C.a);

    static assert(isEnumSafelyConvertible!(A, C));
    static assert(isEnumSafelyConvertible!(B, C));
    static assert(!isEnumSafelyConvertible!(C, A));
    static assert(!isEnumSafelyConvertible!(C, B));
}
