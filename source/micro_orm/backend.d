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

module micro_orm.backend;

import micro_orm.entities : ColumnInfo;
import micro_orm.queries;
import micro_orm.exceptions : MicroOrmException;

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

/**
 * Interface for a query result; compareable to an row in some databases.
 */
interface QueryResult {
    /**
     * Called to get a column's data as string
     * 
     * Params:
     *  index = the index of the data
     *  col = the column/field information
     * 
     * Returns: the string representation of the data inside the database
     */
    string get(size_t index, immutable ColumnInfo col);
}

/**
 * Interface to be implemented by backends
 */
interface Backend {
    /**
     * Called on connection creation; since each connection holds it's own instance of a backend,
     * this is only called once per connection.
     * 
     * Params:
     *  dsn = the dsn for the connection; how this is parsed depends on the backend
     *  user = the user to use
     *  passwd = the password to use
     */
    void connect(string dsn, string user, string passwd);

    /**
     * Called when a connection is closing.
     */
    void close();

    /**
     * Called to ensure presence of an entity's collection. Backends are supposed to create tables / collections here
     * or validate them if they already exists and throw errors if there are any problems.
     * 
     * Throws: $(REF micro_orm.exceptions.MicroOrmException)
     */
    void ensurePresence(string storageName, immutable ColumnInfo[] columns, immutable ColumnInfo[] primarykeys);

    /**
     * Called to execute an select query.
     * 
     * Params:
     *  query = the query to execute
     *  all = helper flag; if true, the caller wants to list all entries; if false, only one is requested and the limit of the query is always 1.
     * 
     * Returns: a list of query results
     */
    QueryResult[] select(BaseSelectQuery query, bool all);

    // TODO: create an result type which contains the sequence/auto-increment id or similar
    /**
     * Called to execute an insert query.
     * 
     * Params:
     *  query = the qery to execute
     */
    void insert(BaseInsertQuery query);

    /**
     * Called to execute an update query.
     * 
     * Params:
     *  query = the qery to execute
     */
    void update(BaseUpdateQuery query);

    /**
     * Called to execute an delete query.
     * 
     * Params:
     *  query = the qery to execute
     */
    void del(BaseDeleteQuery query);

    //Schema[] list();
    //Schema get(string name);
    //Schema create(string name);
    //bool remove(string name);
    //Schema defaultSchema();
}

/**
 * Execption to be throwed when a requested backend could not be found.
 */
class NoSuchBackendException : MicroOrmException {
    this(string name) {
        super("Could not find micro_orm-backend '" ~ name ~ "'");
    }
}

/**
 * Registry for MicroOrm backends
 */
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
        debug (micro_orm_backend_register) {
            import std.stdio;
            writeln("[micro_orm.backend.BackendRegistry] registering '", name, "' backend");
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

/**
 * Helper-template to register an backend for MicroOrm
 */
template RegisterBackend(string name, alias BackendClass) {
    import std.traits;
    pragma(msg, "Registering micro_orm backend '" ~ name ~ "' with type ", fullyQualifiedName!BackendClass);

    static this() {
        BackendRegistry.instance().register!BackendClass(name);
    }
}
