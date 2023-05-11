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
public import micro_orm.queries;

version (micro_orm_hooks) {
    version = micro_orm_hook_insert;
    version = micro_orm_hook_update;
}

/**
 * UDA to apply storage information to a entity
 */
struct Storage {
    /// The name of the entity to use inside the database; this becomes the name of the table / collection.
    string name;

    /// The connection-id this entity should be persisted on
    string connection = null;
}

/**
 * UDA to mark an entity
 */
struct Entity {}

// ======================================================================

alias ColumnInfo = FieldInfo;

/**
 * Template to implement an entity
 */
template BaseEntity(alias T)
{
    import micro_orm.lazylist;
    import micro_orm.exceptions;

    /// Contains the Model data of the Entity
    struct MicroOrmModel {
        import std.traits;
        import micro_orm.entities;

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

        private enum isConst(T) = is(const T == T);

        // go through all field and create the column infos
        private template ColumnGen(size_t i = 0, size_t fi = 0) {
            import micro_orm.entities.fields;
            import micro_orm.entities.relations;
            import micro_orm.active_value;

            static if (i == fieldNames.length) {
                enum ColumnGen = "";
            }
            else static if (hasUDA!(T.tupleof[i], IgnoreField)) {
                static assert(
                    !hasUDA!(T.tupleof[i], Field),
                    "Cannot have both `@IgnoreField` and `@Field` on the same member field: `" ~ fullyQualifiedName!(T.tupleof[i]) ~ "`"
                );
                enum ColumnGen = "" ~ ColumnGen!(i+1, fi);
            }
            else static if (isConst!(fieldTypes[i])) {
                static assert(
                    !hasUDA!(T.tupleof[i], Field) && !hasUDA!(T.tupleof[i], Id),
                    "Cannot have `@Field` or `@Id` on a const member field: `" ~ fullyQualifiedName!(T.tupleof[i]) ~ "`"
                );
                enum ColumnGen = "" ~ ColumnGen!(i+1, fi);
            }
            // else static if (isInstanceOf!(fieldTypes[i], ActiveValue)) {
            //     static assert(
            //         !hasUDA!(T.tupleof[i], Field) && !hasUDA!(T.tupleof[i], Id),
            //         "Cannot have `@Field` or `@Id` on a field of type micro_orm.active_value.ActiveValue: `" ~ fullyQualifiedName!(T.tupleof[i]) ~ "`"
            //     );
            //     enum ColumnGen = "" ~ ColumnGen!(i+1, fi);
            // }
            /* else static if (hasUDA!(T.tupleof[i], OneToOne)) {
                // When refering one-to-one, we "inject" a field of the id-type of the
                // other type, if any.

                alias fieldType = fieldTypes[i];
                static if (!__traits(hasMember, fieldType, "MicroOrmModel")) {
                    static assert(0,
                        "MicroOrm: field `" ~ fullyQualifiedName!(T.tupleof[i]) ~ "` is annotated with `@OneToOne`,"
                            ~ " it needs `" ~ fullyQualifiedName!fieldType ~ "` to be a entity."
                    );
                } else {
                    alias refModel = fieldType.MicroOrmModel;
                    static assert(
                        refModel.PrimaryKeys.length > 0,
                        "MicroOrm: field `" ~ fullyQualifiedName!(T.tupleof[i]) ~ "` is annotated with `@OneToOne`,"
                            ~ " but model of `" ~ fullyQualifiedName!fieldType ~ "` dosnt contain any primary keys."
                    );
                    static assert(
                        !hasUDA!(T.tupleof[i], Id),
                        "MicroOrm: field `" ~ fullyQualifiedName!(T.tupleof[i]) ~ "` is annotated with `@OneToOne`,"
                            ~ " so it cannot be annotated with `@Id`."
                    );

                    static if (hasUDA!(T.tupleof[i], Field)) {
                        alias field_udas = getUDAs!(T.tupleof[i], Field);
                        static assert(
                            field_udas.length == 1,
                            "MicroOrm: field `" ~ fullyQualifiedName!(T.tupleof[i]) ~ "` is annotated with multiple `@Field` annotations."
                        );
                        static if (is(field_udas[0] == Field)) {
                            enum Name = fieldNames[i];
                        } else {
                            static if(field_udas[0].name !is null) {
                                enum Name = field_udas[0].name;
                            } else {
                                enum Name = fieldNames[i];
                            }
                        }
                    } else {
                        enum Name = fieldNames[i];
                    }

                    // A composite primary key must generate a field per component inside the composite key
                    private template RefColumnGen(size_t j = 0) {

                    }

                    import std.conv : to;
                    enum ColumnGen =
                        "imported!\"micro_orm.entities\".FieldInfo("
                            ~ "imported!\"micro_orm.entities.fields\".Field(\"" ~ Name ~ "\"),"
                            ~ "\"" ~ fullyQualifiedName!T ~ "\","
                            ~ "\"" ~ fieldNames[i] ~ "\","
                            ~ to!string(fi) ~ ","
                            ~ to!string(i) ~ ","
                            ~ "false,"
                            ~ "false,"
                        ~ ")" ~ ColumnGen!(i+1, fi);
                }
            } */
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

                static if (hasUDA!(T.tupleof[i], GeneratedValue)) {
                    // is a generated value; look after a member T.__<membername>_gen
                    // which needs to be either a constant of type ValueGenerator or
                    // a static function which returns a ValueGenerator

                    enum generatorMemberName = "__" ~ fieldNames[i] ~ "_gen";
                    static if (hasStaticMember!(T, generatorMemberName)) {
                        alias generatorMember = __traits(getMember, T, generatorMemberName);
                        static if (isFunction!generatorMember) {
                            import std.meta : AliasSeq;
                            static assert(
                                is(ReturnType!generatorMember == ValueGenerator) && is(Parameters!generatorMember == AliasSeq!()),
                                "MicroOrm: field `" ~ fieldNames[i] ~ "` of `" ~ fullyQualifiedName!T ~ "` is annotated with `@GeneratedValue` "
                                    ~ "and there is a static member function `" ~ generatorMemberName ~ "`; it needs to have a return type of `ValueGenerator` and no parameters"
                            );
                        }
                        else {
                            static assert(
                                is(typeof(generatorMember) == const ValueGenerator),
                                "MicroOrm: field `" ~ fieldNames[i] ~ "` of `" ~ fullyQualifiedName!T ~ "` is annotated with `@GeneratedValue` "
                                    ~ "and there is a static member `" ~ generatorMemberName ~ "`, but it needs to be either a function or a static const ValueGenerator"
                            );
                        }
                    } else static if (__traits(hasMember, T, generatorMemberName)) {
                        alias generatorMember = __traits(getMember, T, generatorMemberName);
                        static if (!isConst!(typeof(generatorMember))) {
                            static assert(0,
                                "MicroOrm: field `" ~ fieldNames[i] ~ "` of `" ~ fullyQualifiedName!T ~ "` is annotated with `@GeneratedValue` "
                                    ~ "and there is a member `" ~ generatorMemberName ~ "`, but it needs to be a constant"
                            );
                        }
                    } else {
                        static assert(0,
                            "MicroOrm: field `" ~ fieldNames[i] ~ "` of `" ~ fullyQualifiedName!T ~ "` is annotated with `@GeneratedValue`;"
                                ~ " there must be static member function or constant named `" ~ generatorMemberName ~ "` present as well."
                        );
                    }
                }

                import std.conv : to;
                enum ColumnGen =
                    "imported!\"micro_orm.entities\".ColumnInfo("
                        ~ "imported!\"micro_orm.entities.fields\".Field(\"" ~ Name ~ "\"," ~ Type ~ "),"
                        ~ "\"" ~ fullyQualifiedName!T ~ "\","
                        ~ "\"" ~ fieldNames[i] ~ "\","
                        ~ to!string(fi) ~ ","
                        ~ to!string(i) ~ ","
                        ~ to!string( hasUDA!(T.tupleof[i], Id) ) ~ ","
                        ~ to!string( hasUDA!(T.tupleof[i], GeneratedValue) )
                    ~ ")," ~ ColumnGen!(i+1, fi+1);
            }
        }
        static immutable(FieldInfo[]) Columns = mixin( "[" ~ ColumnGen!() ~ "]" );
        pragma(msg, " - Columns: ");
        static foreach (col; Columns) {
            pragma(msg, "    - ", col);
        }

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
        static immutable(FieldInfo[]) PrimaryKeys = mixin( "[" ~ PrimaryKeyGen!() ~ "]" );
        pragma(msg, " - PrimaryKeys: ");
        static foreach (pk; PrimaryKeys) {
            pragma(msg, "    - ", pk);
        }

        /// Function that's been called on an database connection to ensure the presence of the entity.
        /// It also validates the structure and yields an error if the entity schema on the remote
        /// dosnt matches the one declared.
        static void ensurePresence(imported!"micro_orm".Connection con) {
            // setup all generators
            static foreach (col; MicroOrmModel.Columns) {
                static if (col.generated_value) {
                    mixin(fullyQualifiedName!T ~ ".__" ~ col.member_name ~ "_gen.setup(con);");
                }
            }

            con.backend.ensurePresence(StorageName, Columns, PrimaryKeys);
        }

        import micro_orm.backend : QueryResult;
        static T from_query_result(QueryResult data, imported!"micro_orm".Connection con) {
            auto res = new T();
            template FieldSetterGen(size_t i = 0) {
                static if (i == fieldNames.length) {
                    enum FieldSetterGen = "";
                }
                else static if (hasUDA!(T.tupleof[i], IgnoreField)) {
                    enum FieldSetterGen = "";
                }
                else static if (isConst!(fieldTypes[i])) {
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

        private template GenIdParams(size_t i = 0) {
            static if (i == Columns.length) {
                enum GenIdParams = "";
            }
            else static if (Columns[i].is_primarykey) {
                alias fieldType = fieldTypes[i];
                enum col = Columns[i];
                enum GenIdParams = fieldType.stringof ~ " " ~ col.member_name ~ "," ~ GenIdParams!(i+1);
            }
            else {
                enum GenIdParams = "" ~ GenIdParams!(i+1);
            }
        }
        pragma(msg, " - Generated Id Params: |", GenIdParams!(), "|");

        private template GenIdFilters(string prefix = "", size_t i = 0) {
            static if (i == Columns.length) {
                enum GenIdFilters = "";
            }
            else static if (Columns[i].is_primarykey) {
                enum col = Columns[i];
                enum GenIdFilters = "q.filter!\"" ~ col.name ~ "\"(eq(" ~ prefix ~ col.member_name ~ "))" ~ "; " ~ GenIdFilters!(prefix, i+1);
            }
            else {
                enum GenIdFilters = "" ~ GenIdFilters!(prefix, i+1);
            }
        }
        pragma(msg, " - Generated Id Filters: |", GenIdFilters!(), "|");
        pragma(msg, " - Generated Id Filters: |", GenIdFilters!("this."), "|");
    }

    private {
        import micro_orm.entities.fields : IgnoreField;
        @IgnoreField imported!"micro_orm".Connection __microOrm_con = null;
    }

    /**
     * Creates an insert query for the current entity
     * 
     * Returns: the insert query which inserts the current entity when executed
     */
    imported!"micro_orm.queries".BaseInsertQuery insert() {
        import micro_orm.queries;
        import micro_orm : Connection;
        import std.variant : Variant;
        import std.conv : to;
        import std.traits : fullyQualifiedName;

        import micro_orm.entities.hooks;
        version (micro_orm_hook_insert) {
            mixin EntityHook!(T, "onInsert", BaseInsertQuery);
            mixin( onBefore!() );
        } else {
            static assert(!hasHookMember!(T, "onInsert"), "MicroOrm: can only use __microOrm_onInsert when having version micro_orm_hook_insert");
        }

        Variant[] values;
        ValueGetter[int] value_getters;
        values.reserve( MicroOrmModel.Columns.length );
        static foreach (col; MicroOrmModel.Columns) {
            static if (col.generated_value) {
                values ~= Variant(); // push an empty variant that gets filled in...

                enum generatorMemberName = "__" ~ col.member_name ~ "_gen";
                value_getters[col.index] = ValueGetter((immutable FieldInfo info, Connection con) {
                    mixin( "return " ~ fullyQualifiedName!T ~ "." ~ generatorMemberName ~ ".next(con);" );
                });
            } else {
                static if (col.type == FieldType.Enum) {
                    mixin( "values ~= Variant(to!string( this." ~ col.member_name ~ " ));" );
                } else {
                    mixin( "values ~= Variant( this." ~ col.member_name ~ " );" );
                }
            }
        }

        auto q = new BaseInsertQuery(
            MicroOrmModel.StorageName, MicroOrmModel.ConnectionName,
            MicroOrmModel.Columns, MicroOrmModel.PrimaryKeys,
            values, value_getters
        );

        version (micro_orm_hook_insert) {
            mixin( onExec!() );
            mixin( onAfter!() );
        }

        return q;
    }

    /**
     * Creates an update query for the current entity
     * 
     * Returns: the update query which updates the current entity when executed
     */
    imported!"micro_orm.queries".UpdateQuery!T update() {
        import micro_orm.queries;
        import std.variant : Variant;
        import std.typecons : Tuple;
        import std.conv : to;

        import micro_orm.entities.hooks;
        version (micro_orm_hook_update) {
            mixin EntityHook!(T, "onUpdate", UpdateQuery!T);
            mixin( onBefore!() );
        } else {
            static assert(!hasHookMember!(T, "onUpdate"), "MicroOrm: can only use __microOrm_onUpdate when having version micro_orm_hook_update");
        }

        Variant[] values;
        values.reserve( MicroOrmModel.Columns.length );
        static foreach (col; MicroOrmModel.Columns) {
            static if (col.type == FieldType.Enum) {
                mixin( "values ~= Variant(to!string( this." ~ col.member_name ~ " ));" );
            } else {
                mixin( "values ~= Variant( this." ~ col.member_name ~ " );" );
            }
        }

        auto q = new UpdateQuery!T(
            MicroOrmModel.StorageName, MicroOrmModel.ConnectionName,
            MicroOrmModel.Columns, MicroOrmModel.PrimaryKeys,
            values
        );

        mixin( MicroOrmModel.GenIdFilters!("this.") );

        version (micro_orm_hook_update) {
            mixin( onExec!() );
            mixin( onAfter!() );
        }

        return q;
    }

    /**
     * Creates an delete query for the current entity
     * 
     * Returns: the delete query which deletes the current entity when executed
     */
    imported!"micro_orm.queries".DeleteQuery!T del() {
        import micro_orm.queries;
        auto q = new DeleteQuery!T(
            MicroOrmModel.StorageName, MicroOrmModel.ConnectionName,
            MicroOrmModel.Columns, MicroOrmModel.PrimaryKeys
        );
        mixin( MicroOrmModel.GenIdFilters!("this.") );
        return q;
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

    /**
     * Creates an select query for the entity
     * 
     * Returns: the select query for the entity
     */
    static imported!"micro_orm.queries".SelectQuery!T find() {
        import micro_orm.queries;
        import std.stdio;
        return new SelectQuery!T(
            MicroOrmModel.StorageName, MicroOrmModel.ConnectionName,
            MicroOrmModel.Columns, MicroOrmModel.PrimaryKeys
        );
    }

    /**
     * Creates an select query for the entity for the id(s)
     * 
     * This can be used as a shorthand to create a select query for entities with the specified primary keys.
     * 
     * Returns: the select query for the entity for the id(s)
     */
    mixin(
        "static imported!\"micro_orm.queries\".SelectQuery!T find_by_id(", MicroOrmModel.GenIdParams!(), ") {",
            "import micro_orm.queries.select;",
            "import micro_orm.queries.filters;",
            "auto q = find();",
            MicroOrmModel.GenIdFilters!(),
            "return q;",
        "}"
    );
}