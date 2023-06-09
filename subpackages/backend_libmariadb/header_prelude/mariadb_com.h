// --------------------------------------------------------------------------------
// expose mariadb_com.h symbols
// --------------------------------------------------------------------------------

#define SQLSTATE_LENGTH 5

#define MYSQL_ERRMSG_SIZE	512

typedef struct {} NET;

enum enum_field_types {
    MYSQL_TYPE_DECIMAL, MYSQL_TYPE_TINY,
    MYSQL_TYPE_SHORT,  MYSQL_TYPE_LONG,
    MYSQL_TYPE_FLOAT,  MYSQL_TYPE_DOUBLE,
    MYSQL_TYPE_NULL,   MYSQL_TYPE_TIMESTAMP,
    MYSQL_TYPE_LONGLONG,MYSQL_TYPE_INT24,
    MYSQL_TYPE_DATE,   MYSQL_TYPE_TIME,
    MYSQL_TYPE_DATETIME, MYSQL_TYPE_YEAR,
    MYSQL_TYPE_NEWDATE, MYSQL_TYPE_VARCHAR,
    MYSQL_TYPE_BIT,
    /*
        the following types are not used by client,
        only for mysqlbinlog
    */
    MYSQL_TYPE_TIMESTAMP2,
    MYSQL_TYPE_DATETIME2,
    MYSQL_TYPE_TIME2,
    /* --------------------------------------------- */
    MYSQL_TYPE_JSON=245,
    MYSQL_TYPE_NEWDECIMAL=246,
    MYSQL_TYPE_ENUM=247,
    MYSQL_TYPE_SET=248,
    MYSQL_TYPE_TINY_BLOB=249,
    MYSQL_TYPE_MEDIUM_BLOB=250,
    MYSQL_TYPE_LONG_BLOB=251,
    MYSQL_TYPE_BLOB=252,
    MYSQL_TYPE_VAR_STRING=253,
    MYSQL_TYPE_STRING=254,
    MYSQL_TYPE_GEOMETRY=255,
    MAX_NO_FIELD_TYPES
};
