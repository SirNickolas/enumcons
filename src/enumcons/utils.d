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

struct _supertypeOf(E);

package alias declareSupertypeOf(alias sub) = _supertypeOf!(TypeOf!sub);

package template isSupertypeOf(E) {
    enum isSupertypeOf(alias Uda) = is(Uda == _supertypeOf!E);
}
