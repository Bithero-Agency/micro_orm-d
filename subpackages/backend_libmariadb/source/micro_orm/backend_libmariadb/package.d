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
 * Main module of the libmariadb backend for micro_orm
 * 
 * License:   $(HTTP https://www.gnu.org/licenses/agpl-3.0.html, AGPL 3.0).
 * Copyright: Copyright (C) 2023 Mai-Lapyst
 * Authors:   $(HTTP codeark.it/Mai-Lapyst, Mai-Lapyst)
 */

module micro_orm.backend_libmariadb;

import micro_orm.backend;
import micro_orm.entities;
import micro_orm.exceptions;

import micro_orm.backend_libmariadb.mysql.mysql;

import ministd.optional;

import std.conv : to;
import std.string : toStringz, split, join, replace;
import std.algorithm : map;
import std.variant : Variant;
import std.typecons : Tuple;

debug (micro_orm_mariadb) {
    debug = micro_orm_mariadb_createtable;
    debug = micro_orm_mariadb_delete;
    debug = micro_orm_mariadb_insert;
    debug = micro_orm_mariadb_select;
    debug = micro_orm_mariadb_update;
}

class MariadbException : MicroOrmException {
    mixin ExceptionInheritConstructors;
}

private string quoteValue(string i) {
    return "'" ~ i.replace("'", "\\'") ~ "'";
}

private string quoteValue(FieldType type, Variant v) {
    switch (type) {
        case FieldType.Char: {
            if (v.type() == typeid(char)) {
                char c = v.get!char();
                if (c == '\'') { return "'\''"; }
                return "'" ~ c ~ "'";
            }
            else if (v.type() == typeid(wchar)) {
                import std.digest : toHexString;
                wchar ch = v.get!wchar();
                ubyte* ptr = cast(ubyte*) &ch;
                string res = "";
                for (int i = 1; i >= 0; i--) {
                    ubyte[] data = [ ptr[i] ];
                    res ~= "\\x" ~ data.toHexString();
                }
                return "'" ~ res ~ "'";
            }
            // TODO: char(4) / dchar
            // TODO: char(x)
            break;
        }
        case FieldType.String: { return quoteValue(v.get!string()); }
        // TODO: Text
        case FieldType.TinyInt: { return to!string(v.get!(byte)); }
        case FieldType.TinyUInt: { return to!string(v.get!(ubyte)); }
        case FieldType.SmallInt: { return to!string(v.get!(short)); }
        case FieldType.SmallUInt: { return to!string(v.get!(ushort)); }
        case FieldType.Int: { return to!string(v.get!(int)); }
        case FieldType.UInt: { return to!string(v.get!(uint)); }
        // TODO: BigInt
        case FieldType.Float: { return to!string(v.get!(float)); }
        case FieldType.Double: { return to!string(v.get!(double)); }
        // TODO: Decimal
        // TODO: Binary, VarBinary
        // TODO: Bool
        // TODO: Money
        // TODO: Json
        // TODO: Uuid
        case FieldType.Enum: { return quoteValue(v.get!(string)); }
        // TODO: Custom
        default: {}
    }
    throw new MicroOrmException("Could not quote value of type: " ~ to!string(type));
}

private string quoteName(string i) {
    return "`" ~ i.replace("`", "\\`") ~ "`";
}

class MysqlQueryResult : QueryResult {
    private string[] _row;

    this(char** row, int col_count) {
        _row.reserve(col_count);
        foreach(i; 0..col_count) {
            auto field = row[i];
            _row ~= to!string(field);
        }
    }

    string get(size_t index, immutable ColumnInfo col) {
        return _row[index];
    }
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
            throw new MicroOrmConnectionException("Connection already established!");
        }
        con = mysql_init(null);

        int port = 3306;

        auto options = dsn.split(";");
        foreach (raw_opt; options) {
            auto opt = raw_opt.split("=");
            auto key = opt[0];
            if (opt.length != 2) {
                throw new MicroOrmConnectionException("Malformed option: '" ~ raw_opt ~ "'");
            }
            if (key == "host" || key == "hostname") {
                if (unix_sock !is null) {
                    throw new MicroOrmConnectionException("Cannot set 'hostname' when 'unix_sock' is already set");
                }
                if (host !is null) {
                    throw new MicroOrmConnectionException("Cannot set 'hostname' twice");
                }
                host = toStringz(opt[1]);
            }
            else if (key == "post") {
                port = to!int(opt[1]);
            }
            else if (key == "db_name" || key == "db") {
                if (db_name !is null) {
                    throw new MicroOrmConnectionException("Cannot set 'db_name' twice");
                }
                db_name = toStringz(opt[1]);
            }
            else if (key == "socket" || key == "unix_socket") {
                if (host !is null) {
                    throw new MicroOrmConnectionException("Cannot set 'unix_socket' when 'hostname' is already set");
                }
                if (unix_sock !is null) {
                    throw new MicroOrmConnectionException("Cannot set 'unix_socket' twice");
                }
                unix_sock = toStringz(opt[1]);
            }
            else {
                throw new MicroOrmConnectionException("Unknown option: '" ~ key ~ '"');
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
            throw new MicroOrmConnectionException("Error while connection to server: '" ~ to!string(err) ~ '"');
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

    private string fieldToSqlType(immutable ColumnInfo col) {
        switch (col.type) {
            // TODO: char
            case FieldType.String: {
                if (col.hasData()) {
                    return "varchar(" ~ to!string(col.getSize()) ~ ")";
                } else {
                    return "varchar(255)";
                }
            }
            // TODO: text
            // TODO: more ints
            case FieldType.Int: {
                if (col.hasData()) {
                    return "int(" ~ to!string(col.getSize()) ~ ")";
                } else {
                    return "int";
                }
            }
            // TODO: float, double
            // TODO: decimal
            // TODO: binary, varbinary
            // TODO: bool
            // TODO: money
            // TODO: json
            // TODO: uuid
            case FieldType.Enum: {
                return "enum(" ~ map!quoteValue(col.getVariants()).join(',') ~ ")";
            }
            // TODO: custom
            default: {
                throw new MariadbException("Unknown field type: " ~ to!string(col.type));
            }
        }
    }

    private void create_table(string storageName, immutable ColumnInfo[] columns, immutable ColumnInfo[] primarykeys) {
        string sql = "CREATE TABLE `" ~ storageName ~ "`(";

        foreach (i, col; columns) {
            if (i > 0) {
                sql ~= ",";
            }
            sql ~= quoteName(col.name);
            sql ~= " ";
            sql ~= fieldToSqlType(col);
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

        debug (micro_orm_mariadb_createtable) {
            import std.stdio;
            writeln("[LibMariaDbBackend.create_table("~storageName~",...)]: sql to run:");
            writeln(sql);
        }

        if (mysql_query(con, toStringz(sql))) {
            throw new MariadbException("Failed to create table: " ~ to!string(mysql_error(con)));
        }
    }

    private void verify_table(string storageName, immutable ColumnInfo[] columns) {
        import std.bitmanip : BitArray;

        if (mysql_query(this.con, toStringz("DESCRIBE " ~ quoteName(storageName) ~ ";"))) {
            throw new MicroOrmException("Error while quering DESCRIBE: " ~ to!string(mysql_error(con)));
        }

        bool[] buf = new bool[columns.length];
        buf[0..columns.length] = true;

        // Result has the format: Field,Type,Null,Key,Default,Extra;
        MYSQL_RES* res = mysql_use_result(this.con);

        while (true) {
            MYSQL_ROW row = mysql_fetch_row(res);
            if (row is null) { break; }

            alias findColResult = Tuple!(size_t, immutable ColumnInfo);
            Optional!findColResult findColumn(string field_name) {
                foreach (i, col; columns) {
                    if (col.name == field_name) {
                        return Optional!findColResult.some( findColResult(i, col) );
                    }
                }
                return Optional!findColResult.none();
            }

            string field_name = to!string(row[0]);
            auto maybe_col_search = findColumn(field_name);
            if (maybe_col_search.isNone()) {
                import std.stdio : writeln;
                writeln("Warn: Found column `" ~ field_name ~ "` which is not specified inside the model with storagename `" ~ storageName ~ "`");
                continue;
            }
            auto col_search = maybe_col_search.take();

            bool compareTypes(string got, string expected) {
                import std.string;
                import std.regex;
                if (expected.indexOf('(') == -1) {
                    // expected got no type-params, so lets erase them from the type gotten as well before we compare
                    got = replaceFirst(got, regex("\\(.*\\)"), "");
                }
                import std.stdio;
                writeln("-> got: |",got,"|");
                writeln("-> expected: |",expected,"|");
                return got == expected;
            }

            string got_type = to!string(row[1]);
            string expected_type = fieldToSqlType(col_search[1]);
            if (!compareTypes(got_type, expected_type)) {
                throw new MariadbException(
                    "Table verification failed: table `" ~ storageName ~ "`, column `" ~ field_name ~ "`"
                        ~ ", should have type `" ~ expected_type ~ "` but got `" ~ got_type ~ "` instead."
                );
            }

            // TODO: null, key, default and extra

            buf[ col_search[0] ] = false;
        }

        bool had_errors = false;
        foreach (i, flag; buf) {
            if (flag) {
                import std.stdio : writeln;
                writeln("Error: Could not find column for field `" ~ columns[i].name ~ "` for storagename `" ~ storageName ~ "`");
                had_errors = true;
            }
        }
        if (had_errors) {
            throw new MariadbException("One or more columns couldn't be found in the database. Check output for more information.");
        }
    }

    void ensurePresence(string storageName, immutable ColumnInfo[] columns, immutable ColumnInfo[] primarykeys) {
        if (!has_table(storageName)) {
            this.create_table(storageName, columns, primarykeys);
        } else {
            this.verify_table(storageName, columns);
        }
    }

    string buildWhereClause(immutable(Field[]) fields, const(Tuple!(int, Operation, Variant)[]) filters) {
        if (filters.length > 0) {
            string sql = "";
            foreach (idx, instance; filters) {
                if (idx > 0) { sql ~= ","; }
                ColumnInfo col = fields[instance[0]];
                sql ~= quoteName(col.name);
                final switch (instance[1]) {
                    case Operation.None:
                        throw new MicroOrmException("Operation.None is not allowed");

                    case Operation.Eq:
                        sql ~= " = " ~ quoteValue(col.type, instance[2]);
                        break;
                }
            }
            return sql;
        }
        else {
            return "1";
        }
    }

    string buildSelect(BaseSelectQuery query) {
        string sql = "SELECT ";
        foreach (i, f; query.fields) {
            if (i > 0) { sql ~= ","; }
            sql ~= quoteName(f.name);
        }
        sql ~= " FROM " ~ quoteName(query.storageName);
        sql ~= " WHERE " ~ buildWhereClause(query.fields, query.filters);
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

    QueryResult[] select(BaseSelectQuery query, bool all) {
        string sql = buildSelect(query);
        debug (micro_orm_mariadb_select) {
            import std.stdio;
            writeln("[LibMariaDbBackend.select()]: sql to run:");
            writeln(sql);
        }

        if (mysql_query(this.con, toStringz(sql))) {
            throw new MicroOrmException("Error while quering: " ~ to!string(mysql_error(con)));
        }

        QueryResult[] query_res;

        MYSQL_RES* res = mysql_use_result(this.con);
        query_res.reserve(res.row_count);

        while (true) {
            MYSQL_ROW row = mysql_fetch_row(res);
            if (row is null) { break; }

            import std.stdio;
            foreach (i, f; query.fields) {
                if (i > 0) { write(" | "); }
                write(f.name, "=", to!string(row[i]));
            }
            writeln();

            query_res ~= new MysqlQueryResult(row, res.field_count);
        }
        mysql_free_result(res);

        return query_res;
    }

    string buildInsert(BaseInsertQuery query) {
        string sql = "INSERT INTO " ~ quoteName(query.storageName) ~ " (";
        foreach (i, f; query.fields) {
            if (i > 0) { sql ~= ","; }
            sql ~= quoteName(f.name);
        }
        sql ~= ") VALUES (";
        foreach (i, v; query.values) {
            if (i > 0) { sql ~= ","; }
            sql ~= quoteValue(query.fields[i].type, v);
        }
        sql ~= ");";
        return sql;
    }

    void insert(BaseInsertQuery query) {
        string sql = buildInsert(query);
        debug (micro_orm_mariadb_insert) {
            import std.stdio;
            writeln("[LibMariaDbBackend.insert()]: sql to run:");
            writeln(sql);
        }

        if (mysql_query(this.con, toStringz(sql))) {
            throw new MicroOrmException("Error while quering: " ~ to!string(mysql_error(con)));
        }

        // get's the auto-increment id for the previous query
        auto id = mysql_insert_id(this.con);
    }

    string buildUpdate(BaseUpdateQuery query) {
        import std.algorithm: canFind;
        string sql = "UPDATE " ~ quoteName(query.storageName) ~ " SET ";
        auto _off = 0;
        foreach (i, f; query.fields) {
            // do not update primary keys...
            if (query.primarykeys.canFind(f)) {
                _off++;
                continue;
            }

            if (i > _off) { sql ~= ", "; }
            sql ~= quoteName(f.name) ~ " = " ~ quoteValue(f.type, query.values[i]);
        }
        sql ~= " WHERE " ~ buildWhereClause(query.fields, query.filters);
        sql ~= ";";
        return sql;
    }

    void update(BaseUpdateQuery query) {
        string sql = buildUpdate(query);
        debug (micro_orm_mariadb_update) {
            import std.stdio;
            writeln("[LibMariaDbBackend.update()]: sql to run:");
            writeln(sql);
        }

        if (mysql_query(this.con, toStringz(sql))) {
            throw new MicroOrmException("Error while quering: " ~ to!string(mysql_error(con)));
        }
    }

    string buildDelete(BaseDeleteQuery query) {
        return "DELETE FROM " ~ quoteName(query.storageName) ~ " WHERE " ~ buildWhereClause(query.fields, query.filters) ~ ";";
    }

    void del(BaseDeleteQuery query) {
        string sql = buildDelete(query);
        debug (micro_orm_mariadb_delete) {
            import std.stdio;
            writeln("[LibMariaDbBackend.delete()]: sql to run:");
            writeln(sql);
        }

        if (mysql_query(this.con, toStringz(sql))) {
            throw new MicroOrmException("Error while quering: " ~ to!string(mysql_error(con)));
        }
    }
}

mixin RegisterBackend!("mariadb", LibMariaDbBackend);
mixin RegisterBackend!("mysql", LibMariaDbBackend);
