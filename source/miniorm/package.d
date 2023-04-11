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

module miniorm;

import miniorm.backend;
public import miniorm.entities;
import miniorm.exceptions;

import std.stdio;

class Connection {
    private static shared(string[]) connectionIds;

    private Backend backend;
    private string id;

    private this(string id) {
        this.id = id;
    }

    void ensurePresence(string storageName, immutable ColumnInfo[] columns) {
        backend.ensurePresence(storageName, columns);
    }

    static Connection create(Modules...)(
        string dsn, string user, string password
    ) {
        return create!Modules("default", dsn, user, password);
    }

    static Connection create(Modules...)(
        string id, string dsn, string user, string password
    ) {
        import std.traits;
        import std.algorithm : canFind;

        if (connectionIds.canFind(id)) {
            throw new MiniOrmConnectionException("Cannot name a second connection '" ~ id ~ "'");
        }

        Connection con = new Connection(id);

        import std.string : indexOf;
        auto i = dsn.indexOf(':');
        if (i < 0) {
            throw new MiniOrmConnectionException(
                "Malfromed dsn recieved: '" ~ dsn ~ "'; must be in format '<driver>:<driver specific>'"
            );
        }

        auto driver_name = dsn[0 .. i];
        con.backend = BackendRegistry.instance().create(driver_name);
        try {
            con.backend.connect(dsn[i+1 .. $], user, password);
        } catch (Exception e) {
            throw new MiniOrmConnectionException("Failure in backend's connect() method: ", e);
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
                        enum __code = "imported!\"" ~ moduleName!member ~ "\"." ~ member.stringof ~ ".MiniOrmModel.ensurePresence(con);";
                        mixin(__code);
                    }
                }
            }
        }

        return con;
    }

}

//Connection getConnection(string name) {
//    return new Connection();
//}
//
//Connection createConnection(Driver)(string name, string dsn) {
//    return new Connection();
//}
//
//Connection createConnection(string name, string driver, string dsn) {
//    if (__traits(compiles, "import miniorm.backend_" ~ driver ~ ";")) {
//        assert (0, "Cannot create connection: driver could not be found");
//    }
//    //return new Connection();
//}
