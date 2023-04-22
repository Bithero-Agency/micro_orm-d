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
 * Module for a value generator that returns numeric values in ascending order based on a helper table
 * 
 * License:   $(HTTP https://www.gnu.org/licenses/agpl-3.0.html, AGPL 3.0).
 * Copyright: Copyright (C) 2023 Mai-Lapyst
 * Authors:   $(HTTP codeark.it/Mai-Lapyst, Mai-Lapyst)
 */

module micro_orm.entities.generators.sequence;

import micro_orm : Connection;
import micro_orm.entities : Storage;
import micro_orm.entities.fields : FieldType;
import micro_orm.entities.id;
import std.bigint : BigInt;
import std.variant : Variant;

@Storage("__micro_orm_seq")
private class SeqEntry {
    @Id
    string name;

    BigInt next_seq;

    import micro_orm.entities : BaseEntity;
    mixin BaseEntity!SeqEntry;
}

class SequenceGenerator(alias T) : ValueGenerator
if (is(T == byte) || is(T == ubyte) || is(T == short) || is(T == ushort) || is(T == int) || is(T == uint))
{
    private string name;

    this(string name) {
        this.name = name;
    }

    override void setup(Connection con) const {
        // Ensure presence of sequence entries
        SeqEntry.MicroOrmModel.ensurePresence(con);

        // Ensure that we have a entry for the current name...
        if (SeqEntry.find_by_id(name).one(con).isNone()) {
            auto e = new SeqEntry();
            e.name = name;
            e.next_seq = 1; // always start at 1
            e.insert().exec(con);
        }
    }

    override Variant next(Connection con) const {
        auto e = SeqEntry.find_by_id(name).one(con).take();
        auto i = e.next_seq;
        e.next_seq += 1;
        e.update().exec(con);

        enum Impl(alias U) = "static if (is(T == " ~ U.stringof ~ ")) { return Variant(cast(" ~ U.stringof ~ ") i); }";

        mixin( Impl!byte );
        mixin( Impl!ubyte );
        mixin( Impl!short );
        mixin( Impl!ushort );
        mixin( Impl!int );
        mixin( Impl!uint );
        mixin( Impl!long );
        mixin( Impl!ulong );
    }
}
