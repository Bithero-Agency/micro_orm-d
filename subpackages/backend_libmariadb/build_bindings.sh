#!bash

DSTEP=~/projects/github/dstep/bin/dstep
DEBUG_TRANSFORMS=false

cd source/micro_orm/backend_libmariadb

SKIP_MYSQL_H_SYMS="\
    my_bool my_ulonglong STDCALL my_socket \
    MARIADB_CONST_STRING MA_USED_MEM MA_MEM_ROOT \
    mysql_port mysql_unix_port mariadb_deinitialize_ssl \
    MYSQL_FIELD MYSQL_ROWS MYSQL_ROW_OFFSET \
    MYSQL_DATA MYSQL MYSQL_RES MYSQL_PARAMETERS \
"

FIELD_TYPES="\
    MYSQL_TYPE_DECIMAL MYSQL_TYPE_TINY MYSQL_TYPE_SHORT MYSQL_TYPE_LONG \
    MYSQL_TYPE_FLOAT MYSQL_TYPE_DOUBLE MYSQL_TYPE_NULL MYSQL_TYPE_TIMESTAMP \
    MYSQL_TYPE_LONGLONG MYSQL_TYPE_INT24 MYSQL_TYPE_DATE MYSQL_TYPE_TIME \
    MYSQL_TYPE_DATETIME MYSQL_TYPE_YEAR MYSQL_TYPE_NEWDATE MYSQL_TYPE_VARCHAR \
    MYSQL_TYPE_BIT MYSQL_TYPE_TIMESTAMP2 MYSQL_TYPE_DATETIME2 MYSQL_TYPE_TIME2 \
    MYSQL_TYPE_JSON MYSQL_TYPE_NEWDECIMAL MYSQL_TYPE_ENUM MYSQL_TYPE_SET \
    MYSQL_TYPE_TINY_BLOB MYSQL_TYPE_MEDIUM_BLOB MYSQL_TYPE_LONG_BLOB MYSQL_TYPE_BLOB \
    MYSQL_TYPE_VAR_STRING MYSQL_TYPE_STRING MYSQL_TYPE_GEOMETRY MAX_NO_FIELD_TYPES \
"
SKIP_MARIADB_COM_H_SYMS="\
    SQLSTATE_LENGTH MYSQL_ERRMSG_SIZE NET \
    enum_field_types \
    $FIELD_TYPES \
"
SKIP_MA_LIST_H_SYMS="LIST"

append_skip_syms() {
    local list="$*";
    for sym in $list; do
        SKIP_ARGS="$SKIP_ARGS --skip '$sym'"
    done
}

remove_enum() {
    local in="$1";
    local out="$2";
    local name="$3";
    local members="$4";

    local tmp="$in.\$\$";

    sed -e "/enum $name/,/}/d" "$in" > "$tmp"
    for member in $members; do
        sed -i "/alias $member = $name.$member;/d" "$tmp"
    done
    mv "$tmp" "$out"
}

add_prelude_inc() {
    local file="$1";
    local header="$2";
    echo "#include \"../../../header_prelude/$header\"" | cat - $file > temp && mv temp $file
}
add_prelude() {
    local file="$1";
    local prelude="$2";
    echo "$prelude" | cat - $file > temp && mv temp $file
}

PACKAGE="--package micro_orm.backend_libmariadb.mysql"
IMPORT="--global-import micro_orm.backend_libmariadb.mysql.mysql"

FORCE_REBUILD=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--force)
            FORCE_REBUILD=true
            shift
            ;;
        -*|--*)
            echo "Unknown option $1"
            exit 1
            ;;
        *)
            shift
            ;;
    esac
done

# ================================================================================

decl_needs_file() {
    local sym="$1";
    local file="$2";

    local -g "$sym=false"
    if [ /usr/include/mysql/$file.h -nt ./mysql/$file.d ]; then
        local -g "$sym=true"
    fi
    if $FORCE_REBUILD; then
        local -g "$sym=true"
    fi
}

cleanup_if_needed() {
    local is_needed="$1";
    local file="$2";

    if [[ -f ./mysql/$file && "$is_needed" == true ]]; then
        rm -v ./mysql/$file
    fi
}

decl_needs_file "NEEDS_MYSQL_H" "mysql"
decl_needs_file "NEEDS_MARIADB_COM_H" "mariadb_com"
decl_needs_file "NEEDS_MARIADB_VERSION_H" "mariadb_version"
decl_needs_file "NEEDS_MARIADB_CTYPE_H" "mariadb_ctype"
decl_needs_file "NEEDS_MA_LIST_H" "ma_list"
decl_needs_file "NEEDS_MARIADB_STMT_H" "mariadb_stmt"

cleanup_if_needed "$NEEDS_MYSQL_H" "mysql.d"
cleanup_if_needed "$NEEDS_MARIADB_COM_H" "mariadb_com.d"
cleanup_if_needed "$NEEDS_MARIADB_VERSION_H" "mariadb_version.d"
cleanup_if_needed "$NEEDS_MARIADB_CTYPE_H" "mariadb_ctype.d"
cleanup_if_needed "$NEEDS_MA_LIST_H" "ma_list.d"
cleanup_if_needed "$NEEDS_MARIADB_STMT_H" "mariadb_stmt.d"

# ================================================================================

if $NEEDS_MYSQL_H; then
    echo "translate mysql.h ..."
    $DSTEP /usr/include/mysql/mysql.h -o ./mysql/mysql.d
    sed -i 's/^externimport core.stdc.config;$/module micro_orm.backend_libmariadb.mysql.mysql;\n\nimport core.stdc.config;/' ./mysql/mysql.d
    MYSQL_H_IMPORTS="\
    public import micro_orm.backend_libmariadb.mysql.mariadb_com;\n\
    public import micro_orm.backend_libmariadb.mysql.mariadb_version;\n\
    public import micro_orm.backend_libmariadb.mysql.ma_list;\n\
    public import micro_orm.backend_libmariadb.mysql.mariadb_ctype;\n\
    public import micro_orm.backend_libmariadb.mysql.mariadb_stmt;\
    "
    sed -i "s/^ (C):$/$MYSQL_H_IMPORTS\n\nextern (C):/" ./mysql/mysql.d

    sed '/enum enum_field_types/,/}/!d' ./mysql/mysql.d > ./mysql_snippet.tmp
    sed -i '/enum enum_field_types/,/}/d' ./mysql/mysql.d
    sed -i '/alias MYSQL_TYPE_DECIMAL/e cat ./mysql_snippet.tmp' ./mysql/mysql.d
    rm ./mysql_snippet.tmp

    sed -i 's/enum mysql_library/alias mysql_library/g' ./mysql/mysql.d
    sed -i 's/enum unknown_sqlstate/alias unknown_sqlstate/g' ./mysql/mysql.d

    touch -r /usr/include/mysql/mysql.h ./mysql/mysql.d
fi

# ================================================================================

if $NEEDS_MARIADB_COM_H; then
    echo "translate mariadb_com.h ..."

    cp /usr/include/mysql/mariadb_com.h .
    add_prelude './mariadb_com.h' 'typedef int my_socket;typedef char my_bool;'
    add_prelude './mariadb_com.h' '#include <stddef.h>'

    $DSTEP ./mariadb_com.h -o ./mysql/mariadb_com.d --skip my_socket --skip my_bool

    sed -i 's/0xFFFFFFFF00000000ULL/0xFFFFFFFF00000000UL/' ./mysql/mariadb_com.d
    sed -i 's/1ULL/1UL/g' ./mysql/mariadb_com.d

    MARIADB_COM_HEADER="\
    module micro_orm.backend_libmariadb.mysql.mariadb_com;\n\n\
    import micro_orm.backend_libmariadb.mysql.mysql : my_socket, my_bool;\n\n\
    extern (C):\
    "
    sed -i "s/^extern (C):/$MARIADB_COM_HEADER/" ./mysql/mariadb_com.d

    sed -i 's/c_ulong/ulong/g' ./mysql/mariadb_com.d

    rm ./mariadb_com.h

    touch -r /usr/include/mysql/mariadb_com.h ./mysql/mariadb_com.d
fi

# ================================================================================

if $NEEDS_MARIADB_VERSION_H; then
    echo "translate mariadb_version.h ..."
    cp /usr/include/mysql/mariadb_version.h .
    $DSTEP ./mariadb_version.h -o ./mysql/mariadb_version.d $PACKAGE
    rm ./mariadb_version.h

    touch -r /usr/include/mysql/mariadb_version.h ./mysql/mariadb_version.d
fi

# ================================================================================

if $NEEDS_MARIADB_CTYPE_H; then
    echo "translate mariadb_ctype.h ..."
    cp /usr/include/mysql/mariadb_ctype.h .
    add_prelude './mariadb_ctype.h' '#include <stddef.h>'
    $DSTEP ./mariadb_ctype.h -o ./mysql/mariadb_ctype.d
    MARIADB_CTYPE_HEADER="\
    module micro_orm.backend_libmariadb.mysql.mariadb_ctype;\n\n\
    extern (C):\
    "
    sed -i "s/^extern (C):/$MARIADB_CTYPE_HEADER/" ./mysql/mariadb_ctype.d
    rm ./mariadb_ctype.h

    touch -r /usr/include/mysql/mariadb_ctype.h ./mysql/mariadb_ctype.d
fi

# ================================================================================

if $NEEDS_MA_LIST_H; then
    echo "translate ma_list.h ..."
    cp /usr/include/mysql/ma_list.h .
    $DSTEP ./ma_list.h -o ./mysql/ma_list.d
    MA_LIST_HEADER="\
    module micro_orm.backend_libmariadb.mysql.ma_list;\n\n\
    extern (C):\
    "
    sed -i "s/^extern (C):/$MA_LIST_HEADER/" ./mysql/ma_list.d
    rm ./ma_list.h

    touch -r /usr/include/mysql/ma_list.h ./mysql/ma_list.d
fi

# ================================================================================

if $NEEDS_MARIADB_STMT_H; then
    echo "translate mariadb_stmt.h ..."

    SKIP_ARGS=""
    append_skip_syms $SKIP_MYSQL_H_SYMS
    append_skip_syms $SKIP_MARIADB_COM_H_SYMS

    cp /usr/include/mysql/mariadb_stmt.h .
    add_prelude_inc "./mariadb_stmt.h" 'mysql.h'
    add_prelude_inc "./mariadb_stmt.h" 'mariadb_com.h'
    add_prelude_inc "./mariadb_stmt.h" 'ma_list.h'

    $DSTEP ./mariadb_stmt.h -o ./mysql/mariadb_stmt.d $SKIP_ARGS $PACKAGE $IMPORT

    cp ./mysql/mariadb_stmt.d ./mysql/mariadb_stmt.tmp.d
    remove_enum "./mysql/mariadb_stmt.tmp.d" "./mysql/mariadb_stmt.d" "enum_field_types" "$FIELD_TYPES"
    if $DEBUG_TRANSFORMS; then
        echo "Diff"
        diff -Naur ./mysql/mariadb_stmt.tmp.d ./mysql/mariadb_stmt.d
    fi

    sed -i 's/_Anonymous_0/MYSQL_RES/' ./mysql/mariadb_stmt.d
    sed -i 's/alias MA_MEM_ROOT = _Anonymous_2;//' ./mysql/mariadb_stmt.d
    sed -i 's/alias MYSQL = _Anonymous_3;//' ./mysql/mariadb_stmt.d
    sed -i 's/alias MYSQL_FIELD = _Anonymous_4;//' ./mysql/mariadb_stmt.d
    sed -i 's/alias MYSQL_DATA = _Anonymous_5;//' ./mysql/mariadb_stmt.d
    sed -i 's/alias MYSQL_ROWS = _Anonymous_6;//' ./mysql/mariadb_stmt.d
    sed -i 's/alias LIST = _Anonymous_7;//' ./mysql/mariadb_stmt.d

    rm "./mysql/mariadb_stmt.tmp.d"
    rm "./mariadb_stmt.h"

    touch -r /usr/include/mysql/mariadb_stmt.h ./mysql/mariadb_stmt.d
fi
