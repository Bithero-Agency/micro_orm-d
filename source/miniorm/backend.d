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
 * Module to hold base code for backends
 * 
 * License:   $(HTTP https://www.gnu.org/licenses/agpl-3.0.html, AGPL 3.0).
 * Copyright: Copyright (C) 2023 Mai-Lapyst
 * Authors:   $(HTTP codeark.it/Mai-Lapyst, Mai-Lapyst)
 */

module miniorm.backend;

import miniorm.entities : ColumnInfo, SelectQuery;
import miniorm.exceptions : MiniOrmException;

interface Schema {
    Backend getBackend();

    Database[] list();
    Database get(string name);
    Database create(string name);
    bool remove(string name);
}

interface Database {
    Backend getBackend();
    Schema getSchema();

    Collection[] list();
    Collection get();
    Collection create(string name);
    bool remove(string name);
}

interface Collection {
    Backend getBackend();
    Schema getSchema();
    Database getDatabase();
}

interface Backend {
    void connect(string dsn, string user, string passwd);
    void close();

    void ensurePresence(string storageName, immutable ColumnInfo[] columns, immutable ColumnInfo[] primarykeys);

    void select(SelectQuery query, bool all);

    //Schema[] list();
    //Schema get(string name);
    //Schema create(string name);
    //bool remove(string name);
    //Schema defaultSchema();
}

class NoSuchBackendException : MiniOrmException {
    this(string name) {
        super("Could not find miniorm-backend '" ~ name ~ "'");
    }
}

class BackendRegistry {
    private Backend delegate()[string] constructors;

    private shared this() {}

    static shared(BackendRegistry) instance() {
        static shared BackendRegistry _instance;
        if (!_instance) {
            synchronized {
                if (!_instance) {
                    _instance = new shared(BackendRegistry)();
                }
            }
        }
        return _instance;
    }

    synchronized void register(alias BackendClass)(string name) {
        debug (miniorm_backend_register) {
            import std.stdio;
            writeln("[miniorm.backend.BackendRegistry] registering '", name, "' backend");
        }
        import std.traits;
        constructors[name] = () {
            mixin(
                "return new imported!\"" ~ moduleName!BackendClass ~ "\"." ~ BackendClass.stringof ~ "();"
            );
        };
    }

    synchronized Backend create(string name) {
        auto p = name in constructors;
        if (p !is null) {
            return (*p)();
        } else {
            throw new NoSuchBackendException(name);
        }
    }
}

template RegisterBackend(string name, alias BackendClass) {
    import std.traits;
    pragma(msg, "Registering miniorm backend '" ~ name ~ "' with type ", fullyQualifiedName!BackendClass);

    static this() {
        BackendRegistry.instance().register!BackendClass(name);
    }
}
