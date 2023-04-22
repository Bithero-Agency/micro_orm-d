module micro_orm.entities.fields;

import std.typecons : Tuple;
import micro_orm.exceptions;

// https://dlang.org/spec/type.html#basic-data-types

/// Enum to represent types for serialization to the database
enum FieldType {
    None,

    Char, String,   // uses an optional `size_t` as length
    Text,

    // All use a optional `size_t` as length
    TinyInt, TinyUInt,
    SmallInt, SmallUInt,
    Int, UInt,
    BigInt, BigUInt,

    // use a optional `size_t` as precision
    Float, Double,

    // use two optional `(size_t, size_t)` as precision and scale
    Decimal,

    // DateTime, Timestamp, TimestampWithTZ, Date, Interval,

    Binary,     // use an optional `BlobSize` as size
    VarBinary,  // use a `size_t` as length

    Bool,

    // use two optional `(size_t, size_t)` as precision and scale
    Money,

    Json,

    Uuid,

    Enum, // uses an optional `string[]` for the values

    Custom, // uses an optional `string` for the fully qualified name
}

/// Parameter for the $(REF FieldType.Blob) type
struct BlobSize {
    enum Kind { Tiny, Medium, Long, Blob }
    private {
        Kind kind;
        size_t sz;
    }

    // TODO
}

/**
 * UDA to declare Field data for serialization.
 */
struct Field {
    /// Name of the field on the database; `null` means we use the member's name
    string name = null;

    private FieldType ty = FieldType.None;
    private bool has_data = false;
    private union {
        size_t sz;
        BlobSize blobsz;
        string fqn;
        string[] variants;
        Tuple!(size_t, size_t) prec_scale;
    }

    string typeString() {
        import std.conv : to;

        enum ImplSzType(FieldType ty) =
            "case " ~ ty.stringof ~ ": {" ~
            " if (has_data) { return \"" ~ to!string(ty) ~ "(\" ~ to!string(sz) ~ \")\"; }" ~
            " else { return \"" ~ to!string(ty) ~ "\"; }" ~
            "}"
        ;

        switch (ty) {
            default: { return "Unknown"; }

            mixin( ImplSzType!(FieldType.Char) );
            mixin( ImplSzType!(FieldType.String) );
            case FieldType.Text: { return "Text"; }

            mixin( ImplSzType!(FieldType.TinyInt) );
            mixin( ImplSzType!(FieldType.TinyUInt) );
            mixin( ImplSzType!(FieldType.SmallInt) );
            mixin( ImplSzType!(FieldType.SmallUInt) );
            mixin( ImplSzType!(FieldType.Int) );
            mixin( ImplSzType!(FieldType.UInt) );
            mixin( ImplSzType!(FieldType.BigInt) );
            mixin( ImplSzType!(FieldType.BigUInt) );

            mixin( ImplSzType!(FieldType.Float) );
            mixin( ImplSzType!(FieldType.Double) );

            case FieldType.Decimal: {
                if (has_data) {
                    return "Decimal(" ~ to!string(prec_scale[0]) ~ ", " ~ to!string(prec_scale[1]) ~ ")";
                } else {
                    return "Decimal";
                }
            }

            case FieldType.Binary: {
                if (has_data) {
                    return "Binary(" ~ to!string(blobsz) ~ ")";
                } else {
                    return "Binary";
                }
            }
            case FieldType.VarBinary: { return "VarBinary(" ~ to!string(sz) ~ ")"; }

            case FieldType.Bool: { return "Bool"; }

            case FieldType.Money: {
                if (has_data) {
                    return "Money(" ~ to!string(prec_scale[0]) ~ ", " ~ to!string(prec_scale[1]) ~ ")";
                } else {
                    return "Money";
                }
            }

            case FieldType.Json: { return "Json"; }
            case FieldType.Uuid: { return "Uuid"; }

            case FieldType.Enum: {
                if (has_data) {
                    return "Enum(" ~ to!string(variants) ~ ")";
                } else {
                    return "Enum";
                }
            }
            case FieldType.Custom: {
                if (has_data) {
                    return "Custom(" ~ fqn ~ ")";
                } else {
                    return "Custom";
                }
            }
        }
    }

    // ----- Generic

    this(string name) {
        this.name = name;
    }

    this(string name, FieldType ty) {
        this(ty);
        this.name = name;
    }

    this(FieldType ty) {
        switch (ty) {
            case FieldType.VarBinary:
                throw new MicroOrmFieldException("Fieldtype `VarBinary` needs an mandatiory `size_t` as length");
            default:
                this.ty = ty;
                break;
        }
    }

    @property FieldType type() const {
        return this.ty;
    }

    @property bool hasData() const {
        return this.has_data;
    }

    private void assertHasData() const {
        if (!has_data) {
            throw new MicroOrmFieldException("Cannot get data: no data set");
        }
    }

    // ----- Char, String, all Int's & VarBinary

    this(string name, FieldType ty, size_t sz) {
        this(ty, sz);
        this.name = name;
    }

    this(FieldType ty, size_t sz) {
        switch (ty) {
            case FieldType.Char:
            case FieldType.String:
            case FieldType.TinyInt:
            case FieldType.TinyUInt:
            case FieldType.SmallInt:
            case FieldType.SmallUInt:
            case FieldType.Int:
            case FieldType.UInt:
            case FieldType.BigInt:
            case FieldType.BigUInt:
            case FieldType.Float:
            case FieldType.Double:
            case FieldType.VarBinary:
                this.ty = ty;
                this.has_data = true;
                this.sz = sz;
                break;
            default:
                import std.conv : to;
                throw new MicroOrmFieldException("Fieldtype `" ~ to!string(ty) ~ "` dosn't accepts a single `size_t` as data");
        }
    }

    size_t getSize() const {
        assertHasData();
        switch (this.ty) {
            case FieldType.Char:
            case FieldType.String:
            case FieldType.TinyInt:
            case FieldType.TinyUInt:
            case FieldType.SmallInt:
            case FieldType.SmallUInt:
            case FieldType.Int:
            case FieldType.UInt:
            case FieldType.BigInt:
            case FieldType.BigUInt:
            case FieldType.Float:
            case FieldType.Double:
            case FieldType.VarBinary:
                return this.sz;
            default:
                import std.conv : to;
                throw new MicroOrmFieldException("Fieldtype `" ~ to!string(ty) ~ "` dosn't supports a single `size_t` as data");
        }
    }

    // ----- Binary

    this(string name, BlobSize blobz) {
        this(name, FieldType.Binary, blobsz);
    }

    this(BlobSize blobz) {
        this(FieldType.Binary, blobsz);
    }

    this(string name, FieldType ty, BlobSize blobsz) {
        this(ty, blobsz);
        this.name = name;
    }

    this(FieldType ty, BlobSize blobsz) {
        if (ty != FieldType.Binary) {
            throw new MicroOrmFieldException("Can only set an `BlobSize` when using `FieldType.Binary`");
        }
        this.ty = ty;
        this.has_data = true;
        this.blobsz = blobsz;
    }

    BlobSize getBlobSize() const {
        assertHasData();
        if (this.ty != FieldType.Binary) {
            throw new MicroOrmFieldException("Can only get `BlobSize` data on a `FieldType.Binary`");
        }
        return this.blobsz;
    }

    // ----- Custom

    this(string name, string fqn) {
        this(name, FieldType.Custom, fqn);
    }

    this(string name, FieldType ty, string fqn) {
        this(ty, fqn);
        this.name = name;
    }

    this(FieldType ty, string fqn) {
        if (ty != FieldType.Custom) {
            throw new MicroOrmFieldException("Can only set an fqn when using `FieldType.Custom`");
        }
        this.ty = ty;
        this.has_data = true;
        this.fqn = fqn;
    }

    string getFqn() const {
        assertHasData();
        if (this.ty != FieldType.Custom) {
            throw new MicroOrmFieldException("Can only get fqn on a `FieldType.Custom`");
        }
        return this.fqn;
    }

    // ----- Enum

    this(string name, string[] variants) {
        this(name, FieldType.Enum, variants);
    }

    this(string[] variants) {
        this(FieldType.Enum, variants);
    }

    this(string name, FieldType ty, string[] variants) {
        this(ty, variants);
        this.name = name;
    }

    this(FieldType ty, string[] variants) {
        if (ty != FieldType.Enum) {
            throw new MicroOrmFieldException("Can only set variants when using `FieldType.Enum`");
        }
        this.ty = ty;
        this.has_data = true;
        this.variants = variants;
    }

    const(string[]) getVariants() const {
        assertHasData();
        if (this.ty != FieldType.Enum) {
            throw new MicroOrmFieldException("Can only get variants on a `FieldType.Enum`");
        }
        return this.variants;
    }

    // ----- Decimal & Money

    this(string name, FieldType ty, Tuple!(size_t, size_t) prec_scale) {
        this(ty, prec_scale);
        this.name = name;
    }

    this(FieldType ty, Tuple!(size_t, size_t) prec_scale) {
        switch (ty) {
            case FieldType.Decimal:
            case FieldType.Money:
                this.ty = ty;
                this.has_data = true;
                this.prec_scale = prec_scale;
                break;
            default:
                import std.conv : to;
                throw new MicroOrmFieldException("Fieldtype `" ~ to!string(ty) ~ "` dosn't accepts a `Tuple!(size_t, size_t)` as data");
        }
    }

    Tuple!(size_t, size_t) getPrecScale() const {
        assertHasData();
        switch (this.ty) {
            case FieldType.Decimal:
            case FieldType.Money:
                return this.prec_scale;
            default:
                import std.conv : to;
                throw new MicroOrmFieldException("Fieldtype `" ~ to!string(ty) ~ "` dosn't supports `Tuple!(size_t, size_t)` as data");
        }
    }

}

/**
 * Used to descripe all field information that MicroOrm needs / gathers.
 */
struct FieldInfo {
    Field field;
    alias field this; // act as a "normal" field

    /// Fqn of the parent type that contains the field / member
    string parent_fqn;

    /// Member name of the dlang member
    string member_name;

    /// Index of the field
    int index;

    /// Index of the dlang member
    int member_index;

    /// Flag if the column is a primary key
    bool is_primarykey;

    /// Flag id the value of the column should be generated
    bool generated_value;
}

/**
 * UDA to exclude the annotated field from serialization.
 */
struct IgnoreField {}

/**
 * Template to map a field's type from a native dlang type.
 */
template mapFieldTypeFromNative(alias T) {
    import std.traits : fullyQualifiedName, EnumMembers;

    static if (is(T == struct) || is(T == class)) {
        // TODO: add metadata about embeddable statue; i.e. struct=embedded, class=referenced
        enum mapFieldTypeFromNative = "FieldType.Custom, " ~ fullyQualifiedName!T;
    }
    else static if (is(T == enum)) {
        alias enum_members = EnumMembers!T;

        template Impl(size_t i = 0) {
            static if (i == enum_members.length) {
                enum Impl = "";
            } else {
                enum Impl = "\"" ~ enum_members[i].stringof ~ "\"," ~ Impl!(i+1);
            }
        }

        enum mapFieldTypeFromNative = "FieldType.Enum, [" ~ Impl!() ~ "]";
    }
    else static if (is(T == union) || is(T == interface)) {
        static assert(0, "MicroOrm: Cannot map fieldtype `" ~ T.stringof ~ "`, union and interfaces arent supported");
    }
    else static if (is(T == char)) { enum mapFieldTypeFromNative = "FieldType.Char, 1"; }
    else static if (is(T == wchar)) { enum mapFieldTypeFromNative = "FieldType.Char, 2"; }
    else static if (is(T == dchar)) { enum mapFieldTypeFromNative = "FieldType.Char, 4"; }
    else static if (is(T == string)) { enum mapFieldTypeFromNative = "FieldType.String"; }
    else static if (is(T == byte)) { enum mapFieldTypeFromNative = "FieldType.TinyInt"; }
    else static if (is(T == ubyte)) { enum mapFieldTypeFromNative = "FieldType.TinyUInt"; }
    else static if (is(T == short)) { enum mapFieldTypeFromNative = "FieldType.SmallInt"; }
    else static if (is(T == ushort)) { enum mapFieldTypeFromNative = "FieldType.SmallUInt"; }
    else static if (is(T == int)) { enum mapFieldTypeFromNative = "FieldType.Int"; }
    else static if (is(T == uint)) { enum mapFieldTypeFromNative = "FieldType.UInt"; }
    // TODO: long & ulong (64bit)
    // TODO: cent & ucent (128bit)
    else {
        static assert(0, "MicroOrm: Cannot map unknown fieldtype `" ~ T.stringof ~ "`");
    }
}

/**
 * Helper to determine if a fieldtype is a integer
 */
enum bool isFieldTypeIntKind(FieldType type) = (
    (type == FieldType.TinyInt) || (type == FieldType.TinyUInt)
    || (type == FieldType.SmallInt) || (type == FieldType.SmallUInt)
    || (type == FieldType.Int) || (type == FieldType.UInt)
    || (type == FieldType.BigInt) || (type == FieldType.BigUInt)
);

/**
 * Template to map a fields's type from a native dlang type with the help of an field UDA as hint
 */
template mapFieldTypeFromNativeWithHint(alias T, Field hint) {
    import std.traits : fullyQualifiedName, EnumMembers;
    import std.conv : to;

    enum HintType = hint.type;

    static assert(HintType != FieldType.None, "MicroOrm: fieldhint with `FieldType.None` is not allowed");
    static if (HintType == FieldType.Char) {
        // TODO: wchar (16bit / len 2) & dchar (32bit / len 4)
        static assert(is(T == char), "MicroOrm: can only use `FieldType.Char` when member is of type `char`");
        enum mapFieldTypeFromNativeWithHint = "FieldType.Char, " ~ to!string(hint.getSize());
    }
    else static if (HintType == FieldType.String) {
        static assert(is(T == string), "MicroOrm: can only use `FieldType.String` when member is of type `string`");
        enum mapFieldTypeFromNativeWithHint = "FieldType.String, " ~ to!string(hint.getSize());
    }
    else static if (HintType == FieldType.Text) {
        static assert(is(T == string), "MicroOrm: can only use `FieldType.Text` when member is of type `string`");
        enum mapFieldTypeFromNativeWithHint = "FieldType.String";
    }
    else static if (isFieldTypeIntKind!(HintType)) {
        template IntImpl(args...) {
            static if (args.length == 0) {
                enum IntImpl = "";
            } else {
                alias intTy = args[0];
                alias nativeTy = args[1];
                static if (HintType == intTy) {
                    static assert(is(T == nativeTy), "MicroOrm: can only use `" ~ intTy.stringof ~ "` when member is of type `" ~ nativeTy.stringof ~ "`");
                    enum IntImpl = "FieldType." ~ intTy.stringof ~ ", " ~ to!string(hint.getSize());
                } else {
                    enum IntImpl = IntImpl!( args[2 .. $] );
                }
            }
        }
        enum mapFieldTypeFromNativeWithHint = IntImpl!(
            FieldType.TinyInt, byte,
            FieldType.TinyUInt, ubyte,
            FieldType.SmallInt, short,
            FieldType.SmallUInt, ushort,
            FieldType.Int, int,
            FieldType.UInt, uint,
        );
        // TODO: BigInt
    }
    else static if (HintType == FieldType.Float) {
        static assert(is(T == float), "MicroOrm: can only use `FieldType.Float` when member is of type `float`");
        enum mapFieldTypeFromNativeWithHint = "FieldType.Float, " ~ to!string(hint.getSize());
    }
    else static if (HintType == FieldType.Double) {
        static assert(is(T == double), "MicroOrm: can only use `FieldType.Double` when member is of type `double`");
        enum mapFieldTypeFromNativeWithHint = "FieldType.Double, " ~ to!string(hint.getSize());
    }
    // TODO: Decimal
    // TODO: Binary, VarBinary
    else static if (HintType == FieldType.Bool) {
        static assert(is(T == bool), "MicroOrm: can only use `FieldType.Bool` when member is of type `bool`");
        enum mapFieldTypeFromNativeWithHint = "FieldType.Bool";
    }
    // TODO: Money
    // TODO: Json
    // TODO: Uuid
    // TODO: Enum
    // TODO: Custom
    else {
        static assert(0, "MicroOrm: Unknown fieldtype hint: `" ~ to!string(hint.type) ~ "`");
    }
}

/**
 * Template to perform a compiletime check if a certain type is compareable with a field
 */
template compTimeCheckField(alias T, Field field)
{
    import std.conv : to;
    import std.traits : fullyQualifiedName;
    enum FType = field.type;
    enum ErrorMsgPre  = "MicroOrm: Can only compare field `" ~ field.name ~ "` of type " ~ field.typeString() ~ " with values of type ";
    enum ErrorMsgPost = ", but used type `" ~ fullyQualifiedName!T ~ "`";

    debug (micro_orm_compTimeCheckField) {
        pragma(msg, "compTimeCheckField(T = ", T.stringof, ", field = ", field, ")");
    }

    static if (FType == FieldType.Char) {
        static if (field.getSize() == 1) {
            static assert(is(T == char), ErrorMsgPre ~ "char" ~ ErrorMsgPost);
        }
        else static if (field.getSize() == 2) {
            static assert(is(T == wchar), ErrorMsgPre ~ "wchar" ~ ErrorMsgPost);
        }
        else static if (field.getSize() == 4) {
            static assert(is(T == dchar), ErrorMsgPre ~ "dchar" ~ ErrorMsgPost);
        }
        else {
            static assert(0, "MicroOrm: Misconfigured Field found; invalid length " ~ to!string(field.getSize()) ~ " for fieldtype Char");
        }
    }
    else static if (FType == FieldType.String) {
        static assert(is(T == string), ErrorMsgPre ~ "string" ~ ErrorMsgPost);
    }
    // TODO: Text
    else static if (isFieldTypeIntKind!FType) {
        template IntImpl(args...) {
            static if (args.length == 0) {
                enum IntImpl = true;
            } else {
                alias intTy = args[0];
                alias nativeTy = args[1];
                static if (FType == intTy) {
                    static assert(is(T == nativeTy), ErrorMsgPre ~ nativeTy.stringof ~ ErrorMsgPost);
                    enum IntImpl = true;
                } else {
                    enum IntImpl = IntImpl!( args[2 .. $] );
                }
            }
        }
        enum __checked = IntImpl!(
            FieldType.TinyInt, byte,
            FieldType.TinyUInt, ubyte,
            FieldType.SmallInt, short,
            FieldType.SmallUInt, ushort,
            FieldType.Int, int,
            FieldType.UInt, uint,
        );
        // TODO: BigInt
    }
    else static if (FType == FieldType.Float) {
        static assert(is(T == float), ErrorMsgPre ~ "float" ~ ErrorMsgPost);
    }
    else static if (FType == FieldType.Double) {
        static assert(is(T == double), ErrorMsgPre ~ "double" ~ ErrorMsgPost);
    }
    // TODO: Decimal
    // TODO: Binary, VarBinary
    else static if (FType == FieldType.Bool) {
        static assert(is(T == bool), ErrorMsgPre ~ "bool" ~ ErrorMsgPost);
    }
    // TODO: Money
    // TODO: Json
    // TODO: Uuid
    else static if (FType == FieldType.Enum) {
        // TODO: do a check if T is of the enum type we want...
    }
    // TODO: Custom
    else {
        static assert(0, "Unkown field type: " ~ to!string(FType));
    }

    // Needed so template has an effect
    enum compTimeCheckField = true;
}
