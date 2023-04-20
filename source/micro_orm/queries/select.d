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
 * Module for a select query
 * 
 * License:   $(HTTP https://www.gnu.org/licenses/agpl-3.0.html, AGPL 3.0).
 * Copyright: Copyright (C) 2023 Mai-Lapyst
 * Authors:   $(HTTP codeark.it/Mai-Lapyst, Mai-Lapyst)
 */
module micro_orm.queries.select;

import micro_orm.entities.fields;
import std.typecons : Tuple;
import std.variant : Variant;

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