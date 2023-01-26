module enumcons.conv;

import enumcons.traits;

pure @safe:

To as(To, From)(From e) nothrow @nogc
if (is(From == enum) && is(To == enum) && isEnumSafelyConvertible!(From, To)) {
    assert(false, "Not implemented");
}
