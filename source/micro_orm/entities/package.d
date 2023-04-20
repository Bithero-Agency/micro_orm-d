/*
 * Copyright (C) 2023 Mai-Lapyst
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.
 * 
 * You should have received a copy of the GNU Affero General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

/** 
 * Module to hold code for entities
 * 
 * License:   $(HTTP https://www.gnu.org/licenses/agpl-3.0.html, AGPL 3.0).
 * Copyright: Copyright (C) 2023 Mai-Lapyst
 * Authors:   $(HTTP codeark.it/Mai-Lapyst, Mai-Lapyst)
 */

module micro_orm.entities;

public import micro_orm.entities.fields;
public import micro_orm.entities.id;
import std.typecons : Tuple;
import std.variant : Variant;

struct Storage {
    string name;
    string connection = null;
}

struct Entity {}

// ======================================================================

enum Order {
    Asc,
    Desc,
}

enum Operation {
    None,
    Eq,
}

class Filter(alias T) {
    alias Type = T;
    private T _val;
    private Operation _op;

    this(Operation op, T val) {
        this._op = op;
        this._val = val;
    }

    @property T val() {
        return this._val;
    }

    @property Operation op() {
        return this._op;
    }
}

private template ImplOperation(string funcname, string op) {
    mixin(
        "Filter!T " ~ funcname ~ "(T)(T val) {"
            ~ "return new Filter!T(Operation." ~ op ~ ", val);"
        ~ "}"
    );
}
mixin ImplOperation!("eq", "Eq");

private template ImplSelectQuery(alias T) {
    import std.traits : fullyQualifiedName, isInstanceOf;
    static assert(__traits(hasMember, T, "MicroOrmModel"), "Cannot implement SelectQuery for type `" ~ fullyQualifiedName!T ~ "` which is no entity");

    SelectQuery!T filter(string field, U)(U filter)
    if (isInstanceOf!(Filter, U))
    {
        enum col = T.MicroOrmModel.getColumnByName(field);
        alias Ty = U.Type;
        enum checked = compTimeCheckField!(Ty, col);

        enum colIdx = T.MicroOrmModel.getColumnIndexByName(field);
        _filters ~= Tuple!(int, Operation, Variant)(colIdx, filter.op, Variant(filter.val));
        return this;
    }

    SelectQuery!T filter(string field, V)(V value)
    if (!isInstanceOf!(Filter, V))
    {
        return this.filter!field(new Filter!V(Operation.Eq, value));
    }

    SelectQuery!T order_by(string field, Order ord) {
        this._orders ~= Tuple!(string, Order)(field, ord);
        return this;
    }

    SelectQuery!T order_by_asc(string field) {
        return order_by(field, Order.Asc);
    }

    SelectQuery!T order_by_desc(string field) {
        return order_by(field, Order.Desc);
    }

    SelectQuery!T limit(size_t limit) {
        this._limit = limit;
        return this;
    }

    SelectQuery!T offset(size_t offset) {
        this._offset = offset;
        return this;
    }
}

class BaseSelectQuery {
    private {
        string _storageName;
        string _connectionId;
        immutable(Field[]) _fields;
        immutable(Field[]) _primarykeys;
        Tuple!(int, Operation, Variant)[] _filters;
        Tuple!(string, Order)[] _orders;
        size_t _limit = 0;
        size_t _offset = 0;
    }

    this(
        string storageName, string connectionId,
        immutable(Field[]) fields, immutable(Field[]) primarykeys
    ) {
        this._storageName = storageName;
        this._connectionId = connectionId;
        this._fields = fields;
        this._primarykeys = primarykeys;
    }

    @property string storageName() const {
        return this._storageName;
    }

    @property string connectionId() const {
        return this._connectionId;
    }

    @property immutable(Field[]) fields() const {
        return this._fields;
    }

    @property immutable(Field[]) primarykeys() const {
        return this._primarykeys;
    }

    @property const(Tuple!(int, Operation, Variant)[]) filters() const {
        return this._filters;
    }

    @property const(Tuple!(string, Order)[]) orders() const {
        return this._orders;
    }

    size_t getLimit() const {
        return this._limit;
    }

    size_t getOffset() const {
        return this._offset;
    }
}

/// Represents a select query
class SelectQuery(alias T) : BaseSelectQuery {
    this(
        string storageName, string connectionId,
        immutable(Field[]) fields, immutable(Field[]) primarykeys
    ) {
        super(storageName, connectionId, fields, primarykeys);
    }

    mixin ImplSelectQuery!T;

    private BaseSelectQuery toBase() {
        auto base = new BaseSelectQuery(storageName, connectionId, fields, primarykeys);
        base._filters = this._filters;
        base._orders = this._orders;
        base._limit = this._limit;
        base._offset = this._offset;
        return base;
    }

    T[] all(imported!"micro_orm".Connection con) {
        auto results = con.backend.select(this.toBase(), true);

        T[] entities;
        entities.reserve(results.length);

        foreach (res; results) {
            entities ~= T.MicroOrmModel.from_query_result(res);
        }

        return entities;
    }

}

template isField(alias of)
{
    template isField(alias toCheck)
    {
        import std.traits : isFunction, isAggregateType, isBasicType, fullyQualifiedName;
        alias member = __traits(getMember, of, toCheck);
        pragma(msg, "isField(of=",of,")(toCheck=",toCheck,"): member=",fullyQualifiedName!member);
        // !is(BuiltinTypeOf!T)
        enum isField = !isFunction!member && !isAggregateType!member;
    }
}

alias ColumnInfo = Field;

// struct ColumnInfo {
//     bool isAggregateType;
//     string type;
//     string name;
// }

template BaseEntity(alias T)
{
    import micro_orm.lazylist;
    import micro_orm.exceptions;

    /// Contains the Model data of the Entity
    struct MicroOrmModel {
        import std.traits;

        pragma(msg, "Build entity `" ~ fullyQualifiedName!T ~ "`");

        enum entityName = T.stringof;

        static if (hasUDA!(T, Storage)) {
            alias storage_udas = getUDAs!(T, Storage);
            static assert (storage_udas.length == 1, "An entity can only have one `@Storage` annotation: `" ~ fullyQualifiedName!T ~ "`");
            enum StorageName = storage_udas[0].name;
            static if (storage_udas[0].connection !is null) {
                enum ConnectionName = storage_udas[0].connection;
            } else {
                enum ConnectionName = "default";
            }
        } else {
            enum StorageName = entityName;
            enum ConnectionName = "default";
        }
        pragma(msg, " - Storage name: ", StorageName);
        pragma(msg, " - Storage connection: ", ConnectionName);

        alias fieldTypes = Fields!T;
        alias fieldNames = FieldNameTuple!T;
        static assert(fieldTypes.length == fieldNames.length, "FieldTypeTuple and FieldNameTuple dont have the same length!");

        // go through all field and create the column infos
        private template ColumnGen(size_t i = 0) {
            import micro_orm.entities.fields;

            static if (i == fieldNames.length) {
                enum ColumnGen = "";
            }
            else static if (hasUDA!(T.tupleof[i], IgnoreField)) {
                static assert(
                    !hasUDA!(T.tupleof[i], Field),
                    "Cannot have both `@IgnoreField` and `@Field` on the same member field: `" ~ fullyQualifiedName!(T.tupleof[i]) ~ "`"
                );
                enum ColumnGen = "" ~ ColumnGen!(i+1);
            }
            else {
                alias fieldType = fieldTypes[i];

                static if (hasUDA!(T.tupleof[i], Field)) {
                    alias field_udas = getUDAs!(T.tupleof[i], Field);
                    static assert(
                        field_udas.length == 1,
                        "Member fields can only have one `@Field` annotation: `" ~ fullyQualifiedName!(T.tupleof[i]) ~ "`"
                    );
                    static if (is(field_udas[0] == Field)) {
                        enum Name = fieldNames[i];
                        enum Type = mapFieldTypeFromNative!fieldType;
                    } else {
                        static if(field_udas[0].name !is null) {
                            enum Name = field_udas[0].name;
                        } else {
                            enum Name = fieldNames[i];
                        }

                        static if(field_udas[0].type == FieldType.None) {
                            enum Type = mapFieldTypeFromNative!fieldType;
                        } else {
                            enum Type = mapFieldTypeFromNativeWithHint!(fieldType, field_udas[0]);
                        }
                    }
                } else {
                    enum Name = fieldNames[i];
                    enum Type = mapFieldTypeFromNative!fieldType;
                }

                enum ColumnGen =
                    "imported!\"micro_orm.entities\".ColumnInfo("
                        ~ "\"" ~ Name ~ "\","
                        ~ Type
                    ~ ")," ~ ColumnGen!(i+1);
            }
        }
        static immutable Columns = mixin( "[" ~ ColumnGen!() ~ "]" );
        pragma(msg, " - Columns: ", Columns);

        // get all fields annotated with @Id and make primary keys out of them
        private template PrimaryKeyGen(size_t i = 0) {
            static if (i == fieldNames.length) {
                enum PrimaryKeyGen = "";
            }
            else static if (hasUDA!(T.tupleof[i], IgnoreField)) {
                static assert(
                    !hasUDA!(T.tupleof[i], Field),
                    "Cannot have both `@IgnoreField` and `@Id` on the same member field: `" ~ fullyQualifiedName!(T.tupleof[i]) ~ "`"
                );
                enum PrimaryKeyGen = "" ~ PrimaryKeyGen!(i+1);
            }
            else static if (hasUDA!(T.tupleof[i], Id)) {
                import std.conv : to;
                enum PrimaryKeyGen = "Columns[" ~ to!string(i) ~ "]," ~ PrimaryKeyGen!(i+1);
            }
            else {
                enum PrimaryKeyGen = "" ~ PrimaryKeyGen!(i+1);
            }
        }
        static immutable PrimaryKeys = mixin( "[" ~ PrimaryKeyGen!() ~ "]" );
        pragma(msg, " - PrimaryKeys: ", PrimaryKeys);

        /// Function that's been called on an database connection to ensure the presence of the entity.
        /// It also validates the structure and yields an error if the entity schema on the remote
        /// dosnt matches the one declared.
        static void ensurePresence(imported!"micro_orm".Connection con) {
            con.backend.ensurePresence(StorageName, Columns, PrimaryKeys);
        }

        import micro_orm.backend : QueryResult;
        static T from_query_result(QueryResult data) {
            auto res = new T();
            template FieldSetterGen(size_t i = 0) {
                static if (i == fieldNames.length) {
                    enum FieldSetterGen = "";
                }
                else static if (hasUDA!(T.tupleof[i], IgnoreField)) {
                    enum FieldSetterGen = "";
                }
                else {
                    import std.conv : to;
                    enum FieldSetterGen =
                        "res." ~ fieldNames[i] ~ " = "
                        ~ "imported!\"std.conv\".to!(" ~ fieldTypes[i].stringof ~ ")( "
                            ~ "data.get( " ~ to!string(i) ~ ", Columns[" ~ to!string(i) ~ "] )"
                        ~ " );"
                        ~ FieldSetterGen!(i+1);
                }
            }
            mixin( FieldSetterGen!() );
            return res;
        }

        static immutable(ColumnInfo) getColumnByName(string name) {
            foreach (col; Columns) {
                if (col.name == name) {
                    return col;
                }
            }
            throw new MicroOrmFieldException("Unknown field: `" ~ name ~ "` for entity `" ~ fullyQualifiedName!T ~ "`");
        }

        static int getColumnIndexByName(string name) {
            foreach (idx, col; Columns) {
                if (col.name == name) {
                    return cast(int) idx;
                }
            }
            throw new MicroOrmFieldException("Unknown field: `" ~ name ~ "` for entity `" ~ fullyQualifiedName!T ~ "`");
        }
    }

    void save(imported!"micro_orm".Connection con) {
        import std.traits : fullyQualifiedName;
        if (con.id != MicroOrmModel.ConnectionName) {
            throw new MicroOrmException(
                "Cannot save entity of type `" ~ fullyQualifiedName!T ~ "`"
                    ~ " which requires the connection-id `" ~ MicroOrmModel.ConnectionName ~ "`"
                    ~ " onto a connection that has a id of `" ~ con.id ~ "`"
            );
        }
    }

    static SelectQuery!T find() {
        import std.stdio;
        return new SelectQuery!T(
            MicroOrmModel.StorageName, MicroOrmModel.ConnectionName,
            MicroOrmModel.Columns, MicroOrmModel.PrimaryKeys
        );
    }


}