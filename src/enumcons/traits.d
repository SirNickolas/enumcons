module enumcons.traits;

nothrow pure @safe @nogc:

template isEnumSubtype(Sub, Super)
if (is(Sub == enum) && is(Super == enum) && __traits(isIntegral, Sub, Super)) {
    import enumcons.utils: subtypeInfo;

    enum isEnumSubtype = __traits(compiles, subtypeInfo!(Sub, Super));
}

template isEnumSafelyConvertible(From, To) if (is(From == enum) && __traits(isIntegral, From, To)) {
    static if (is(From: To))
        enum isEnumSafelyConvertible = true;
    else
        enum isEnumSafelyConvertible = isEnumSubtype!(From, To);
}

template isEnumPossiblyConvertible(From, To)
if (is(From == enum) && is(To == enum) && __traits(isIntegral, From, To)) {
    import enumcons.utils: subtypeInfo;

    static if (isEnumSubtype!(To, From))
        enum isEnumPossiblyConvertible = subtypeInfo!(To, From).allowDowncast;
    else
        enum isEnumPossiblyConvertible = false;
}
