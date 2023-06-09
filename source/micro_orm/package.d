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
 * Main module
 * 
 * License:   $(HTTP https://www.gnu.org/licenses/agpl-3.0.html, AGPL 3.0).
 * Copyright: Copyright (C) 2023 Mai-Lapyst
 * Authors:   $(HTTP codeark.it/Mai-Lapyst, Mai-Lapyst)
 */

module micro_orm;

import micro_orm.backend;
public import micro_orm.entities;
import micro_orm.exceptions;

import std.stdio;

/**
 * A connection to a database
 */
class Connection {
    private static shared(string[]) connectionIds;

    private Backend _backend;
    private string _id;

    private this(string id) {
        this._id = id;
    }

    @property string id() {
        return this._id;
    }

    @property Backend backend() {
        return this._backend;
    }

    /**
     * Creates a new connection
     * 
     * Generic Params:
     *  Modules = the modules to be used for entities to persist onto the connection
     * 
     * Params:
     *  dsn = format: `<driver>:<backend-dsn>`
     *  user = the user to use
     *  password = the password to use
     * 
     * Returns: a brand-new connection
     */
    static Connection create(Modules...)(
        string dsn, string user, string password
    ) {
        return create!Modules("default", dsn, user, password);
    }

    /**
     * Creates a new connection
     * 
     * Generic Params:
     *  Modules = the modules to be used for entities to persist onto the connection
     * 
     * Params:
     *  id = id of the connection
     *  dsn = format: `<driver>:<backend-dsn>`
     *  user = the user to use
     *  password = the password to use
     * 
     * Returns: a brand-new connection
     */
    static Connection create(Modules...)(
        string id, string dsn, string user, string password
    ) {
        import std.traits;
        import std.algorithm : canFind;

        if (connectionIds.canFind(id)) {
            throw new MicroOrmConnectionException("Cannot name a second connection '" ~ id ~ "'");
        }

        Connection con = new Connection(id);

        import std.string : indexOf;
        auto i = dsn.indexOf(':');
        if (i < 0) {
            throw new MicroOrmConnectionException(
                "Malfromed dsn recieved: '" ~ dsn ~ "'; must be in format '<driver>:<driver specific>'"
            );
        }

        auto driver_name = dsn[0 .. i];
        con._backend = BackendRegistry.instance().create(driver_name);
        try {
            con.backend.connect(dsn[i+1 .. $], user, password);
        } catch (Exception e) {
            throw new MicroOrmConnectionException("Failure in backend's connect() method: ", e);
        }

        foreach (mod; Modules) {
            foreach (name; __traits(allMembers, mod)) {
                alias member = __traits(getMember, mod, name);
                static if (hasUDA!(member, Entity)) {
                    alias entity_udas = getUDAs!(member, Entity);
                    static assert(
                        entity_udas.length == 1,
                        "Multiple `@Entity` annotations are not allowed: `" ~ fullyQualifiedName!member ~ "`"
                    );

                    alias storage_udas = getUDAs!(member, Storage);
                    static if (storage_udas.length > 0) {
                        static assert(
                            storage_udas.length == 1,
                            "Multiple `@Storage` annotations are not allowed: `" ~ fullyQualifiedName!member ~ "`"
                        );
                        static if (storage_udas[0].connection !is null) {
                            enum __connectionName = storage_udas[0].connection;
                        } else {
                            enum __connectionName = "default";
                        }
                    } else {
                        enum __connectionName = "default";
                    }

                    if (__connectionName == id) {
                        enum __code = "imported!\"" ~ moduleName!member ~ "\"." ~ member.stringof ~ ".MicroOrmModel.ensurePresence(con);";
                        mixin(__code);
                    }
                }
            }
        }

        return con;
    }

}
