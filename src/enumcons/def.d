module enumcons.def;

import std.meta: allSatisfy, staticMap;
import enumcons.traits;
public import enumcons.traits: unknownValue;

private nothrow pure @safe:

// template Concat(...)
// template Unite(...)
// template Merge(...)
// source.as!Combined // Always succeeds. Don't forget to handle `Source == Combined`.
// combined.to!Source // `Source._` if unrepresentable. Only if it is defined, of course.
// combined.assertTo!Source // `AssertError` if lossless conversion is not possible.
// combined.tryTo!Source // `ConvException` if lossless conversion is not possible.

string _generateOne(E)(in string attrPrefix, long offset) {
    import std.conv: to;

    string result;
    static foreach (j, memberName; __traits(allMembers, E)) {{
        alias member = __traits(getMember, E, memberName);
        alias attributes = __traits(getAttributes, member);
        static if (attributes.length)
            result ~= attrPrefix ~ j.to!string ~ ' ';
        result ~= memberName ~ '=' ~ (offset + member).to!string ~ ',';
    }}
    return result;
}

@nogc unittest {
    enum E { b, c, a, d = -4, e, f = 10, g, h = 1 }

    static assert(_generateOne!E(`@b0_`, 2) == `b=2,c=3,a=4,d=-2,e=-1,f=12,g=13,h=3,`);
}

string _generateRenumber(enums...)(in string prefix) {
    import std.conv: to;

    string result;
    long offset;
    static foreach (i, e; enums) {{
        static if (!is(e E))
            alias E = typeof(e);
        static if (i)
            offset -= E.min;
        result ~= _generateOne!E('@' ~ prefix ~ i.to!string ~ '_', offset);
        offset += E.max + 1L;
    }}
    return result;
}

@nogc unittest {
    enum A { a, b = -1, c, d }
    enum B { x, y = -1, z, w = z }

    static assert(_generateRenumber!(A, B)(`a`) == `a=0,b=-1,c=0,d=1,x=3,y=2,z=3,w=3,`);
    static assert(_generateRenumber(`a`) == ``);
}

alias _memberNames(alias e) = __traits(allMembers, _TypeOf!e);

template _ConcatWithBase(Base, enums...) {
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
        enum _ConcatWithBase: Base {`, _generateRenumber!enums(prefix), '}'
    );
}

public template Concat(enums...)
if (__traits(isIntegral, enums) && allSatisfy!(_isEnumOrEnumMember, enums)) {
    // `enums.length >= 1` because `__traits(isIntegral)` would have returned `false` otherwise.
    alias Concat = _ConcatWithBase!(_CommonType!enums, enums);
}

/// ditto
public template ConcatWithBase(Base, enums...)
if (enums.length && __traits(isIntegral, Base, enums) && allSatisfy!(_isEnumOrEnumMember, enums)) {
    alias ConcatWithBase = _ConcatWithBase!(Base, enums);
}

///
@nogc unittest {
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

template _ConcatWithBaseInitLast(Base, enums...) {
    static assert(!is(Base == enum),
        "Specifying another enum as a base type for your enum is currently unsupported. " ~
        "Use `std.traits.{CommonType, OriginalType}`",
    );
    static assert(false, "Not implemented");
}

/// Like `ConcatWithBase`, except that the resulting enum's `.init` value will be that of the last
/// passed argument, not first. In every other aspect, including the numbering scheme, they are
/// exactly the same.
public template ConcatInitLast(enums...)
if (__traits(isIntegral, enums) && allSatisfy!(_isEnumOrEnumMember, enums)) {
    // `enums.length >= 1` because `__traits(isIntegral)` would have returned `false` otherwise.
    alias ConcatInitLast = _ConcatWithBaseInitLast!(_CommonType!enums, enums);
}

/// ditto
public template ConcatWithBaseInitLast(Base, enums...)
if (enums.length && __traits(isIntegral, Base, enums) && allSatisfy!(_isEnumOrEnumMember, enums)) {
    alias ConcatWithBaseInitLast = _ConcatWithBaseInitLast!(Base, enums);
}

///
version (none)
@nogc unittest {
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
