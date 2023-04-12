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
 * Main module of the libmariadb backend for miniorm
 * 
 * License:   $(HTTP https://www.gnu.org/licenses/agpl-3.0.html, AGPL 3.0).
 * Copyright: Copyright (C) 2023 Mai-Lapyst
 * Authors:   $(HTTP codeark.it/Mai-Lapyst, Mai-Lapyst)
 */

module miniorm.backend_libmariadb;

import miniorm.backend;
import miniorm.entities;
import miniorm.exceptions;

import miniorm.backend_libmariadb.mysql.mysql;

import std.conv : to;
import std.string : toStringz, split, join, replace;
import std.algorithm : map;

class MariadbException : MiniOrmException {
    mixin ExceptionInheritConstructors;
}

private string quoteValue(string i) {
    return "'" ~ i.replace("'", "\\'") ~ "'";
}

private string quoteName(string i) {
    return "`" ~ i.replace("`", "\\`") ~ "`";
}

class LibMariaDbBackend : Backend {
    private MYSQL* con = null;
    private {
        // store these to prevent dlang to free these
        const(char)* host = null;
        const(char)* unix_sock = null;
        const(char)* db_name = null;
    }

    ~this() {
        this.close();
    }

    private void assertConnected() {
        assert(con !is null, "Connection must be established!");
    }

    void connect(string dsn, string user, string passwd) {
        if (con !is null) {
            throw new MiniOrmConnectionException("Connection already established!");
        }
        con = mysql_init(null);

        int port = 3306;

        auto options = dsn.split(";");
        foreach (raw_opt; options) {
            auto opt = raw_opt.split("=");
            auto key = opt[0];
            if (opt.length != 2) {
                throw new MiniOrmConnectionException("Malformed option: '" ~ raw_opt ~ "'");
            }
            if (key == "host" || key == "hostname") {
                if (unix_sock !is null) {
                    throw new MiniOrmConnectionException("Cannot set 'hostname' when 'unix_sock' is already set");
                }
                if (host !is null) {
                    throw new MiniOrmConnectionException("Cannot set 'hostname' twice");
                }
                host = toStringz(opt[1]);
            }
            else if (key == "post") {
                port = to!int(opt[1]);
            }
            else if (key == "db_name" || key == "db") {
                if (db_name !is null) {
                    throw new MiniOrmConnectionException("Cannot set 'db_name' twice");
                }
                db_name = toStringz(opt[1]);
            }
            else if (key == "socket" || key == "unix_socket") {
                if (host !is null) {
                    throw new MiniOrmConnectionException("Cannot set 'unix_socket' when 'hostname' is already set");
                }
                if (unix_sock !is null) {
                    throw new MiniOrmConnectionException("Cannot set 'unix_socket' twice");
                }
                unix_sock = toStringz(opt[1]);
            }
            else {
                throw new MiniOrmConnectionException("Unknown option: '" ~ key ~ '"');
            }
        }

        if (
            mysql_real_connect(
                con, host, toStringz(user), toStringz(passwd),
                db_name, port, unix_sock, 0
            ) == null
        ) {
            auto err = mysql_error(con);
            mysql_close(con);
            throw new MiniOrmConnectionException("Error while connection to server: '" ~ to!string(err) ~ '"');
        }
    }

    void close() {
        if (con is null) {
            return;
        }

        mysql_close(con);
        this.con = null;
    }

    private bool has_db(string name) {
        auto str = toStringz(name);

        // TODO: verify that mysql_list_dbs does not uses the string after this method returns
        MYSQL_RES* res = mysql_list_dbs(this.con, str);
        if (res is null) {
            throw new MariadbException("Error while listing databases: " ~ to!string( mysql_error(con) ));
        }

        if (res.row_count < 1) {
            return false;
        }

        while (true) {
            MYSQL_ROW row = mysql_fetch_row(res);
            if (row is null) {
                break;
            }
            if (*row == str) {
                return true;
            }
        }
        return false;
    }

    private bool has_table(string name) {
        auto str = toStringz(name);

        // TODO: verify that mysql_list_tables does not uses the string after this method returns
        MYSQL_RES* res = mysql_list_tables(this.con, str);
        if (res is null) {
            throw new MariadbException("Error while listing tables: " ~ to!string( mysql_error(con) ));
        }

        if (res.row_count > 1) {
            throw new MariadbException("Error while listing tables: recieved more than one result row when using 'LIKE'.");
        }

        return res.row_count == 1;
    }

    private void create_table(string storageName, immutable ColumnInfo[] columns, immutable ColumnInfo[] primarykeys) {
        string sql = "CREATE TABLE `" ~ storageName ~ "`(";

        foreach (i, col; columns) {
            if (i > 0) {
                sql ~= ",";
            }
            sql ~= quoteName(col.name);
            sql ~= " ";
            switch (col.type) {
                // TODO: char
                case FieldType.String: {
                    if (col.hasData()) {
                        sql ~= "VARCHAR(" ~ to!string(col.getSize()) ~ ")";
                    } else {
                        sql ~= "VARCHAR(255)";
                    }
                    break;
                }
                // TODO: text
                // TODO: more ints
                case FieldType.Int: {
                    if (col.hasData()) {
                        sql ~= "INT(" ~ to!string(col.getSize()) ~ ")";
                    } else {
                        sql ~= "INT";
                    }
                    break;
                }
                // TODO: float, double
                // TODO: decimal
                // TODO: binary, varbinary
                // TODO: bool
                // TODO: money
                // TODO: json
                // TODO: uuid
                case FieldType.Enum: {
                    sql ~= "ENUM(" ~ map!quoteValue(col.getVariants()).join(',') ~ ")";
                    break;
                }
                // TODO: custom
                default: {
                    throw new MariadbException("Unknown field type: " ~ to!string(col.type));
                }
            }
        }

        if (primarykeys.length > 0) {
            sql ~= ", PRIMARY KEY(";
            foreach (i, key; primarykeys) {
                if (i > 0) {
                    sql ~= ",";
                }
                sql ~= quoteName(key.name);
            }
            sql ~= ")";
        }

        sql ~= ");";
        // TODO: somehow get metadata...

        debug (miniorm_mariadb_createtable) {
            import std.stdio;
            writeln("[LibMariaDbBackend.create_table("~storageName~",...)]: sql to run:");
            writeln(sql);
        }

        if (mysql_query(con, toStringz(sql))) {
            throw new MariadbException("Failed to create table: " ~ to!string(mysql_error(con)));
        }
    }

    private void verify_table(string storageName, immutable ColumnInfo[] columns) {
        // TODO: implement verify_table
    }

    void ensurePresence(string storageName, immutable ColumnInfo[] columns, immutable ColumnInfo[] primarykeys) {
        if (!has_table(storageName)) {
            this.create_table(storageName, columns, primarykeys);
        } else {
            this.verify_table(storageName, columns);
        }
    }

    string buildSelect(SelectQuery query) {
        string sql = "SELECT ";
        foreach (i, f; query.fields) {
            if (i > 0) { sql ~= ","; }
            sql ~= quoteName(f.name);
        }
        sql ~= " FROM " ~ quoteName(query.storageName);
        sql ~= " WHERE 1";
        if (query.orders.length > 0) {
            sql ~= " ORDER BY ";
            foreach (i, o; query.orders) {
                if (i > 0) { sql ~= ","; }
                sql ~= quoteName(o[0]) ~ " ";
                final switch (o[1]) {
                    case Order.Asc: sql ~= "ASC"; break;
                    case Order.Desc: sql ~= "DESC"; break;
                }
            }
        }
        if (query.getLimit() > 0) {
            sql ~= " LIMIT " ~ to!string(query.getLimit());
        }
        if (query.getOffset() > 0) {
            sql ~= " LIMIT " ~ to!string(query.getOffset()) ~ ", 18446744073709551615";
        }
        return sql ~ ";";
    }

    void select(SelectQuery query, bool all) {
        string sql = buildSelect(query);
        debug (miniorm_mariadb_select) {
            import std.stdio;
            writeln("[LibMariaDbBackend.select()]: sql to run:");
            writeln(sql);
        }

        if (mysql_query(this.con, toStringz(sql))) {
            throw new MiniOrmException("Error while quering: " ~ to!string(mysql_error(con)));
        }

        MYSQL_RES* res = mysql_use_result(this.con);
        while (true) {
            MYSQL_ROW row = mysql_fetch_row(res);
            if (row is null) { break; }

            import std.stdio;
            foreach (i, f; query.fields) {
                if (i > 0) { write(" | "); }
                write(f.name, "=", to!string(row[i]));
            }
            writeln();
        }
        mysql_free_result(res);
    }
}

mixin RegisterBackend!("mariadb", LibMariaDbBackend);
mixin RegisterBackend!("mysql", LibMariaDbBackend);
