module enumcons.traits;

nothrow pure @safe @nogc:

template isEnumSafelyConvertible(From, To) if (is(From == enum) && is(To == enum)) {
    import std.meta: anySatisfy;
    import enumcons.utils: isSupertypeOf;

    // TODO: Implement recursive check.
    enum isEnumSafelyConvertible = anySatisfy!(isSupertypeOf!From, __traits(getAttributes, To));
}
