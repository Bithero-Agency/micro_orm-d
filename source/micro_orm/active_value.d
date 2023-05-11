module micro_orm.active_value;

import ministd.optional;

struct ActiveValue(alias T)
{
    static assert(
        is(T == class) || is(T == interface),
        "MicroOrm: ActiveValue can only hold classes or interfaces; got `" ~ T.stringof ~ "`"
    );

    private {
        bool is_set = false;
        T val = null;
    }

    @property bool isSet() { return is_set; }

    T get() {
        return val;
    }

    void set(T newVal) {
        // TODO
        is_set = true;
        val = newVal;
    }

    void set(Option!T maybe_newVal) {
        is_set = maybe_newVal.isSome();
        if (is_set) {
            val = maybe_newVal.take();
        }
    }
}