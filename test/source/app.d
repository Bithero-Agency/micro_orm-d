module app;

import std.stdio;
import core.stdc.stdio : printf;
import std.string : toStringz;

import micro_orm.backend_libmariadb;
import micro_orm.backend_libmariadb.mysql.mysql;

import micro_orm;
import micro_orm.backend : QueryResult;
import micro_orm.entities.generators.sequence;

struct Other {}

enum SomeEnum {
	SE_ONE,
	SE_TWO,
	SE_THREE,
}

import std.bigint;

@Entity
@Storage("person")
class Person {
	@Id
	@GeneratedValue
	int id;

	static const ValueGenerator __id_gen = new SequenceGenerator!int("seq_person");

	//@Field(FieldType.String, 255)
	string name;

	SomeEnum en;

	// @Field
	// @Field("zzz")
	int age;

	@IgnoreField
	Other o;

	@Field(FieldType.BigInt)
	BigInt bi;

	// static Person from_query_result(QueryResult data) {
	// 	auto res = new Person();
	// 	res.name = data.get!string( Person.MicroOrmModel.Columns[0] );
	// 	return res;
	// }

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

int test_mysql(string[] args) {
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
			con, toStringz(host), toStringz(user), toStringz(pass),
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

string[string] readDotEnv() {
	import std.file : readText;
	import std.string : split, splitLines;

	string[string] res;

	auto dotenv = readText("./.env");
	foreach (line; splitLines(dotenv)) {
		auto data = line.split("=");
		res[data[0]] = data[1];
	}

	return res;
}

int main(string[] args) {

	// Person.find();
	auto env = readDotEnv();

	auto con = Connection.create!app(
		"mysql:host=" ~ env["DB_HOST"] ~ ";db_name=" ~ env["DB_NAME"], env["DB_USER"], env["DB_PASS"]
	);

	auto q = Person.find()
		.order_by_asc("name")
		//.filter!"en"(SomeEnum.SE_ONE)
		.offset(0);
	auto list = q.all(con);
	foreach (p; list) {
		writeln("name: `", p.name, "` | ", "age: ", p.age, "` | ", "en: ", p.en);
	}

	{
		auto maybe_p = q.one(con);
		if (maybe_p.isSome()) {
			auto p = maybe_p.take();
			writeln("name: `", p.name, "` | ", "age: ", p.age, "` | ", "en: ", p.en);
			p.en = SomeEnum.SE_ONE;
			p.update().exec(con);
		}
	}

	{
		auto p = new Person();
		p.name = "Maria Muster";
		p.age = 30;
		p.en = SomeEnum.SE_ONE;
		p.insert().exec(con);
		//p.del().exec(con);
	}

	// sqlite://filepath?param=value


	//return test_mysql(args);
	return 0;
}