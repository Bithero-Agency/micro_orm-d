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

module miniorm.entities;

public import miniorm.entities.fields;
public import miniorm.entities.id;
import std.typecons : Tuple;

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

/// Represents a select query
class SelectQuery {
    private {
        string _storageName;
        string _connectionId;
        immutable(Field[]) _fields;
        immutable(Field[]) _primarykeys;
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

    SelectQuery order_by(string field, Order ord) {
        this._orders ~= Tuple!(string, Order)(field, ord);
        return this;
    }

    SelectQuery order_by_asc(string field) {
        return order_by(field, Order.Asc);
    }

    SelectQuery order_by_desc(string field) {
        return order_by(field, Order.Desc);
    }

    @property const(Tuple!(string, Order)[]) orders() const {
        return this._orders;
    }

    SelectQuery limit(size_t limit) {
        this._limit = limit;
        return this;
    }

    size_t getLimit() const {
        return this._limit;
    }

    SelectQuery offset(size_t offset) {
        this._offset = offset;
        return this;
    }

    size_t getOffset() const {
        return this._offset;
    }

    void all(imported!"miniorm".Connection con) {
        con.backend.select(this, true);
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
    import miniorm.lazylist;
    import miniorm.exceptions;

    /// Contains the Model data of the Entity
    struct MiniOrmModel {
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
            import miniorm.entities.fields;

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
                    "imported!\"miniorm.entities\".ColumnInfo("
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
        static void ensurePresence(imported!"miniorm".Connection con) {
            con.backend.ensurePresence(StorageName, Columns, PrimaryKeys);
        }

        //import std.variant;
        //static T build(Variant[] data) {}
    }

    void save(imported!"miniorm".Connection con) {
        import std.traits : fullyQualifiedName;
        if (con.id != MiniOrmModel.ConnectionName) {
            throw new MiniOrmException(
                "Cannot save entity of type `" ~ fullyQualifiedName!T ~ "`"
                    ~ " which requires the connection-id `" ~ MiniOrmModel.ConnectionName ~ "`"
                    ~ " onto a connection that has a id of `" ~ con.id ~ "`"
            );
        }
    }

    static SelectQuery find() {
        import std.stdio;
        return new SelectQuery(
            MiniOrmModel.StorageName, MiniOrmModel.ConnectionName,
            MiniOrmModel.Columns, MiniOrmModel.PrimaryKeys
        );
    }


}