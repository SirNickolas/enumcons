module enumcons.traits;

import std.meta: staticMap;
import std.traits: CommonType, OriginalType;

package nothrow pure @safe @nogc:

public struct unknownValue {
    string memberName;
}

/// Like `typeof(x)`, but does nothing if `x` is already a type.
template _TypeOf(alias x) {
    static if (is(x))
        alias _TypeOf = x;
    else
        alias _TypeOf = typeof(x);
}

unittest {
    enum E { a }

    static assert(is(_TypeOf!E == E));
    static assert(is(_TypeOf!(E.a) == E));
}

enum _isEnumOrEnumMember(alias x) = is(x == enum) || is(typeof(x) == enum);

unittest {
    enum I { a }
    enum C { a = 'x' }
    enum R { a = 1.5 }
    enum S { a = "x" }

    static assert(_isEnumOrEnumMember!I);
    static assert(_isEnumOrEnumMember!(I.a));
    static assert(_isEnumOrEnumMember!C);
    static assert(_isEnumOrEnumMember!(C.a));
    static assert(_isEnumOrEnumMember!R);
    static assert(_isEnumOrEnumMember!(R.a));
    static assert(_isEnumOrEnumMember!S);
    static assert(_isEnumOrEnumMember!(S.a));

    static assert(!_isEnumOrEnumMember!bool);
    static assert(!_isEnumOrEnumMember!true);
}

alias _OriginalType(alias x) = OriginalType!(_TypeOf!x);
alias _CommonType(enums...) = CommonType!(staticMap!(_OriginalType, enums));
