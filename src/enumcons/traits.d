module enumcons.traits;

nothrow pure @safe @nogc:

template isEnumSubtype(Sub, Super)
if (is(Sub == enum) && is(Super == enum) && __traits(isIntegral, Sub, Super)) {
    import enumcons.utils: offsetForUpcast;

    enum isEnumSubtype = __traits(compiles, offsetForUpcast!(Sub, Super));
}

template isEnumSafelyConvertible(From, To) if (is(From == enum) && __traits(isIntegral, From, To)) {
    static if (is(From: To))
        enum isEnumSafelyConvertible = true;
    else
        enum isEnumSafelyConvertible = isEnumSubtype!(From, To);
}
