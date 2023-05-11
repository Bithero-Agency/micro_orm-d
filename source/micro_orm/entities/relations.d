module micro_orm.entities.relations;

// struct OneToOne {}
// struct OneToMany {}
// struct ManyToOne {}
// struct ManyToMany {}

// class RelationContainer {}



/*

How relations (should) work:
- set via setter, eg. person.job = new Job()
- on insert / update:
  - insert refered value if not already
  - update the reverse if neccessary (if refered value was persisted already)
- on delete:
  - cascade delete if relation needs it (e.g. OneToOne)

- when the current entity is new, ID values have not been generated yet; they are only
  valid once inserted, as such we need to hook into the insert execution AFTER it was inserted.

problems:
- 



*/








template OneToOne(
    alias Ty, string name,
    string inverseOf = ""
)
{
    import std.traits;
    private enum activeValueTy = "imported!\"micro_orm.active_value\".ActiveValue!(" ~ Ty.stringof ~ ")";

    pragma(msg, "Build OneToOne relation `", name , "` of type `", fullyQualifiedName!Ty ~ "`");

    alias fieldTypes = Fields!Ty;
    alias fieldNames = FieldNameTuple!Ty;

    private template MakeRefFields(size_t i = 0) {
        static if (i >= fieldNames.length) {
            enum MakeRefFields = "";
        }
        else static if (hasUDA!(Ty.tupleof[i], Id)) {
            enum MakeRefFields =
                fieldTypes[i].stringof ~ " " ~ name ~ "_" ~ fieldNames[i] ~ ";"
                    ~ MakeRefFields!(i + 1)
            ;
        }
        else {
            enum MakeRefFields = MakeRefFields!(i + 1);
        }
    }

    pragma(msg, " - ref-fields: |", MakeRefFields!(), "|");
    mixin (
        "private {",
            "@IgnoreField ", activeValueTy, " __" ~ name, ";",
            // create ref-fields to id's of the other type...
            MakeRefFields!(),
        "}",
    );

    private template MakeFindByIdArgs(size_t i = 0) {
        static if (i >= fieldNames.length) {
            enum MakeFindByIdArgs = "";
        }
        else static if (hasUDA!(Ty.tupleof[i], Id)) {
            enum MakeFindByIdArgs =
                "this." ~ name ~ "_" ~ fieldNames[i] ~ ","
                    ~ MakeFindByIdArgs!(i + 1)
            ;
        }
        else {
            enum MakeFindByIdArgs = MakeFindByIdArgs!(i + 1);
        }
    }
    pragma(msg, " - findById args: |", MakeFindByIdArgs!(), "|");

    private template InverseOfSetter(string prefix) {
        static if (inverseOf != "") {
            import micro_orm.active_value;
            alias inverseOfMember = __traits(getMember, Ty, inverseOf);
            static if (is(typeof(inverseOfMember) == ActiveValue)) {
                enum InverseOfSetter = prefix ~ "." ~ inverseOf ~ ".set(this);";
            } else {
                enum InverseOfSetter = prefix ~ "." ~ inverseOf ~ " = this;";
            }
        } else {
            enum InverseOfSetter = "";
        }
    }

    // make the getter
    mixin(
        "@property ", Ty.stringof, " ", name, "() {",
            "if (!__" ~ name ~ ".isSet && this.__microOrm_con !is null) {",
                "__" ~ name ~ ".set(",
                    Ty.stringof,
                        ".find_by_id(", MakeFindByIdArgs!(), ")",
                        ".one(this.__microOrm_con)",
                ");",
                InverseOfSetter!("__" ~ name ~ ".get()"),
            "}",
            "return __" ~ name ~ ".get();",
        "}"
    );

    private template MakeRefFieldSetters(string from, size_t i = 0) {
        static if (i >= fieldNames.length) {
            enum MakeRefFieldSetters = "";
        } else static if (hasUDA!(Ty.tupleof[i], Id)) {
            enum MakeRefFieldSetters =
                "this." ~ name ~ "_" ~ fieldNames[i]
                    ~ " = " ~ from ~ "." ~ fieldNames[i] ~ ";"
                    ~ MakeRefFieldSetters!(from, i + 1);
        } else {
            enum MakeRefFieldSetters = MakeRefFieldSetters!(from, i + 1);
        }
    }
    pragma(msg, " - ref-field setters: |", MakeRefFieldSetters!("newVal"), "|");

    // make the setter
    mixin(
        "@property void ", name, "(", Ty.stringof, " newVal) {",
            "__" ~ name ~ ".set(newVal);",
            MakeRefFieldSetters!("newVal"),
            InverseOfSetter!("newVal"),
        "}"
    );
}

