import std.stdio;
import core.stdc.stdio : printf;

import miniorm.backend_libmariadb.mysql.mysql;
import miniorm.models;

@Entity
class Person {
	mixin BaseEntity!Person;


}


//struct MYSQL {}
//extern (C) MYSQL* mysql_init(MYSQL* mysql);
//extern (C) const(char*) mysql_error(MYSQL* mysql);
//extern (C) MYSQL* mysql_real_connect(
//	MYSQL* mysql,
//	const char* host,
//	const char* user,
//	const char* passwd,
//	const char* db,
//	uint port,
//	const char* unix_socket,
//	ulong clientflag
//);
//extern (C) void mysql_close(MYSQL* sock);

int main(string[] args) {
	if (args.length != 3) {
		writeln("need 3 arguments");
		return 1;
	}

	string host = args[0];
	string user = args[1];
	string pass = args[2];

	MYSQL* con = mysql_init(null);

	if (con is null) {
		printf("error in init: %s\n", mysql_error(con));
		return 1;
	}

	if (
		mysql_real_connect(
			con, host, user, pass,
			null, 3306, null, 0
		) == null
	) {
		printf("error in connect: %s\n", mysql_error(con));
		mysql_close(con);
		return 1;
	}

	MYSQL_RES* res = mysql_list_dbs(con, null);
	if (res is null) {
		printf("error in mysql_list_dbs: %s\n", mysql_error(con));
		mysql_close(con);
		return 1;
	}
	printf("db count: %ld\n", res.row_count);
	while (true) {
		MYSQL_ROW row = mysql_fetch_row(res);
		if (row is null) {
			break;
		}
		printf("db: %s\n", *row);
	}
	mysql_free_result(res);

	// -----------------------------

	if (mysql_query(con, "SELECT * from utf8conv_test.test1;")) {
		printf("error in mysql_query: %s\n", mysql_error(con));
		mysql_close(con);
		return 1;
	}

	auto fcount = mysql_field_count(con);
	printf("field count: %d\n", fcount);

	MYSQL_FIELD* fields = mysql_fetch_fields(res);
	for (auto i = 0; i < fcount; i++) {
		printf("field %d:\n", i);
		printf("  - name: %s\n", fields[i].name);
		printf("  - table: %s\n", fields[i].table);
		printf("  - db: %s\n", fields[i].db);
	}

	res = mysql_use_result(con);
	while (true) {
		MYSQL_ROW row = mysql_fetch_row(res);
		if (row is null) {
			break;
		}
		printf("row: '%s'\n", row[0]);
		printf("row: '%s'\n", row[1]);
	}
	mysql_free_result(res);

	// -----------------------------

	mysql_close(con);
	return 0;
}
