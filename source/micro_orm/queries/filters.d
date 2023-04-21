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
 * Module for a query filters; used by SelectQuery and UpdateQuery
 * 
 * License:   $(HTTP https://www.gnu.org/licenses/agpl-3.0.html, AGPL 3.0).
 * Copyright: Copyright (C) 2023 Mai-Lapyst
 * Authors:   $(HTTP codeark.it/Mai-Lapyst, Mai-Lapyst)
 */
module micro_orm.queries.filters;

/**
 * Operations for an filter
 */
enum Operation {
    /// No operation; used as default value
    None,

    /// Equality operation; value must equal other
    Eq,
}

/**
 * Filter for queries which stores a value of a generic type T and a operation
 */
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

/**
 * Template to help implementing `filter!""(filter)` methods for queries that can hold filters.
 */
template ImplFilterQuery(alias T, alias QueryType) {
    import std.traits : fullyQualifiedName, isInstanceOf;
    static assert(__traits(hasMember, T, "MicroOrmModel"), "Cannot use ImplFilterQuery for type `" ~ fullyQualifiedName!T ~ "` which is no entity");

    QueryType!T filter(string field, U)(U filter)
    if (isInstanceOf!(Filter, U))
    {
        enum col = T.MicroOrmModel.getColumnByName(field);
        alias Ty = U.Type;
        enum checked = compTimeCheckField!(Ty, col);

        enum colIdx = T.MicroOrmModel.getColumnIndexByName(field);
        static if (col.type == FieldType.Enum) {
            import std.conv : to;
            _filters ~= Tuple!(int, Operation, Variant)(colIdx, filter.op, Variant( to!string(filter.val) ));
        }
        else {
            _filters ~= Tuple!(int, Operation, Variant)(colIdx, filter.op, Variant(filter.val));
        }
        return this;
    }

    QueryType!T filter(string field, V)(V value)
    if (!isInstanceOf!(Filter, V))
    {
        return this.filter!field(new Filter!V(Operation.Eq, value));
    }
}
