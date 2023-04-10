// --------------------------------------------------------------------------------
// expose mysql.h symbols
// --------------------------------------------------------------------------------

#include <stdarg.h>

#include <sys/types.h>
typedef char my_bool;
typedef unsigned long long my_ulonglong;

#if !defined(_WIN32)
    #define STDCALL
#else
    #define STDCALL __stdcall
#endif

#ifndef my_socket_defined
    #define my_socket_defined
    #if defined(_WIN64)
        #define my_socket unsigned long long
    #elif defined(_WIN32)
        #define my_socket unsigned int
    #else
        typedef int my_socket;
    #endif
#endif

//#include "./mariadb_com.h"
//#include "./ma_list.h"
//#include "./mariadb_ctype.h"

typedef struct {} MARIADB_CONST_STRING;

#ifndef ST_MA_USED_MEM_DEFINED
    #define ST_MA_USED_MEM_DEFINED
    typedef struct {} MA_USED_MEM;
    typedef struct {} MA_MEM_ROOT;
#endif

extern unsigned int mysql_port;
extern char *mysql_unix_port;
extern unsigned int mariadb_deinitialize_ssl;

typedef struct {} MYSQL_FIELD;

typedef struct {} MYSQL_ROWS;
typedef MYSQL_ROWS* MYSQL_ROW_OFFSET;

typedef struct {} MYSQL_DATA;

typedef struct {} MYSQL;

typedef struct {} MYSQL_RES;

typedef struct {} MYSQL_PARAMETERS;
