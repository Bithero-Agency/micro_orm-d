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
 * Module for a update query
 * 
 * License:   $(HTTP https://www.gnu.org/licenses/agpl-3.0.html, AGPL 3.0).
 * Copyright: Copyright (C) 2023 Mai-Lapyst
 * Authors:   $(HTTP codeark.it/Mai-Lapyst, Mai-Lapyst)
 */
module micro_orm.queries.update;

import micro_orm.entities.fields;
import micro_orm.exceptions;
import micro_orm.queries.filters;
import micro_orm : Connection;
import ministd.optional : Option;
import std.typecons : Tuple;
import std.variant : Variant;

class BaseUpdateQuery {
    private {
        string _storageName;
        string _connectionId;
        immutable(Field[]) _fields;
        immutable(Field[]) _primarykeys;

        Variant[] _values;
        Tuple!(int, Operation, Variant)[] _filters;
    }

    this(
        string storageName, string connectionId,
        immutable(Field[]) fields, immutable(Field[]) primarykeys,
        Variant[] values = [],
        Tuple!(int, Operation, Variant)[] filters = []
    ) {
        this._storageName = storageName;
        this._connectionId = connectionId;
        this._fields = fields;
        this._primarykeys = primarykeys;
        this._values = values;
        this._filters = filters;
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

    @property const(Variant[]) values() const {
        return this._values;
    }

    @property const(Tuple!(int, Operation, Variant)[]) filters() const {
        return this._filters;
    }

    void exec(Connection con) {
        con.backend.update(this);
    }
}
