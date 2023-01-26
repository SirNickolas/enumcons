module enumcons.traits;

nothrow pure @safe @nogc:

template isEnumSafelyConvertible(From, To) if (is(From == enum) && __traits(isIntegral, From, To)) {
    static if (is(From: To))
        enum isEnumSafelyConvertible = true;
    else {
        import enumcons.utils: offsetForUpcast;

        enum isEnumSafelyConvertible = __traits(compiles, offsetForUpcast!(From, To));
    }
}
