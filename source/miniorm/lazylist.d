module miniorm.lazylist;

import std.container : DList;

class LazyList(alias Item) {
    private DList!Item _inner;

    int opApply(scope int delegate(ref Item) dg)
    {
        int result = 0;

        // first iterate over any items we might already have
        foreach (item; _inner) {
            result = dg(item);
            if (result) {
                break;
            }
        }

        return result;
    }
}